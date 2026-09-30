import Foundation
import LyricCore
import UIKit

#if canImport(SpotifyiOS)
import SpotifyiOS
#endif

/// Follows Spotify through the Spotify iOS SDK (App Remote).
///
/// Setup (see README): add the `SpotifyiOS` Swift package, set `SPOTIFY_CLIENT_ID` in `project.yml`, and register
/// the redirect URI `<scheme>://spotify-login-callback` in the Spotify developer dashboard. The project compiles
/// without the SDK; the source then reports itself unavailable.
@MainActor
final class SpotifySource: NSObject, NowPlayingSource {
    let kind: PlaybackSource = .spotify
    var onUpdate: ((SourceUpdate) -> Void)?
    var onStatusChange: ((SourceStatus) -> Void)?
    var canSeek: Bool { true }

    fileprivate(set) var status: SourceStatus = .idle {
        didSet { if status != oldValue { onStatusChange?(status) } }
    }

    fileprivate static let tokenKey = "spotify.accessToken"
    fileprivate var isRunning = false

    fileprivate var accessToken: String? {
        get { UserDefaults.standard.string(forKey: Self.tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.tokenKey) }
    }

#if canImport(SpotifyiOS)
    fileprivate struct Values {
        var uri: String
        var title: String
        var artist: String
        var album: String
        var duration: TimeInterval
        var position: TimeInterval
        var isPaused: Bool
        var receivedAt: Date

        init(_ state: SPTAppRemotePlayerState) {
            uri = state.track.uri
            title = state.track.name
            artist = state.track.artist.name
            album = state.track.album.name
            duration = TimeInterval(state.track.duration) / 1000
            position = TimeInterval(state.playbackPosition) / 1000
            isPaused = state.isPaused
            receivedAt = Date()
        }

        func currentPosition(at date: Date = Date()) -> TimeInterval {
            isPaused ? position : min(position + date.timeIntervalSince(receivedAt), duration)
        }
    }

    private lazy var configuration = SPTConfiguration(
        clientID: AppConfig.spotifyClientID,
        redirectURL: AppConfig.spotifyRedirectURL
    )

    private lazy var appRemote: SPTAppRemote = {
        let remote = SPTAppRemote(configuration: configuration, logLevel: .error)
        remote.delegate = self
        return remote
    }()

    private var latest: Values?

    // MARK: NowPlayingSource

    func start() {
        guard AppConfig.isSpotifyConfigured else {
            status = .unavailable(String(localized: "Spotify isn't available in this version yet."))
            return
        }
        isRunning = true
        if let token = accessToken {
            status = .connecting
            appRemote.connectionParameters.accessToken = token
            appRemote.connect()
        } else {
            status = .needsPermission
        }
    }

    func stop() {
        isRunning = false
        latest = nil
        if appRemote.isConnected { appRemote.disconnect() }
        status = .idle
    }

    func togglePlayPause() {
        guard appRemote.isConnected else { return }
        if latest?.isPaused ?? true {
            appRemote.playerAPI?.resume(nil)
        } else {
            appRemote.playerAPI?.pause(nil)
        }
    }

    func skipNext() { appRemote.playerAPI?.skip(toNext: nil) }
    func skipPrevious() { appRemote.playerAPI?.skip(toPrevious: nil) }
    func seek(to time: TimeInterval) { appRemote.playerAPI?.seek(toPosition: Int(time * 1000), callback: nil) }

    // MARK: Auth & lifecycle

    /// Opens Spotify to authorize this app, then returns through `handleOpenURL`.
    func authorize() {
        guard AppConfig.isSpotifyConfigured else {
            status = .unavailable(String(localized: "Spotify isn't available in this version yet."))
            return
        }
        isRunning = true
        status = .connecting
        _ = appRemote.authorizeAndPlayURI("")
    }

    func handleOpenURL(_ url: URL) {
        guard let parameters = appRemote.authorizationParameters(from: url) else { return }
        if let token = parameters[SPTAppRemoteAccessTokenKey] {
            accessToken = token
            appRemote.connectionParameters.accessToken = token
            appRemote.connect()
        } else if let message = parameters[SPTAppRemoteErrorDescriptionKey] {
            status = .unavailable(message)
        }
    }

    func sceneDidBecomeActive() {
        guard isRunning, !appRemote.isConnected, let token = accessToken else { return }
        appRemote.connectionParameters.accessToken = token
        appRemote.connect()
    }

    func sceneWillResignActive() {
        if appRemote.isConnected { appRemote.disconnect() }
    }

    // MARK: SDK events (main actor)

    fileprivate func connectionEstablished() {
        status = .connected
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: nil)
        appRemote.playerAPI?.getPlayerState { [weak self] result, _ in
            guard let state = result as? SPTAppRemotePlayerState else { return }
            Task { @MainActor in self?.handle(state) }
        }
    }

    fileprivate func handle(_ state: SPTAppRemotePlayerState) {
        let values = Values(state)
        let trackChanged = values.uri != latest?.uri
        latest = values
        emit(artwork: nil)
        if trackChanged {
            appRemote.imageAPI?.fetchImage(forItem: state.track, with: CGSize(width: 600, height: 600)) { [weak self] image, _ in
                guard let image = image as? UIImage else { return }
                Task { @MainActor in
                    guard self?.latest?.uri == values.uri else { return }
                    self?.emit(artwork: image)
                }
            }
        }
    }

    private func emit(artwork: UIImage?) {
        guard let values = latest else { return }
        let now = Date()
        let track = TrackInfo(
            title: values.title,
            artist: values.artist,
            album: values.album,
            duration: values.duration > 0 ? values.duration : nil,
            source: .spotify,
            externalID: values.uri
        )
        onUpdate?(SourceUpdate(
            track: track,
            isPlaying: !values.isPaused,
            position: values.currentPosition(at: now),
            artwork: artwork,
            timestamp: now
        ))
    }

    fileprivate func connectionFailed(_ message: String) {
        // A stale token and "Spotify is not running" both land here; ask for a fresh authorization.
        accessToken = nil
        status = isRunning ? .needsPermission : .unavailable(message)
    }

    fileprivate func connectionLost() {
        if isRunning { status = .connecting }
    }
#else
    func start() {
        status = .unavailable(String(localized: "Spotify SDK is not linked. See the README."))
    }

    func stop() { status = .idle }
    func authorize() { start() }
    func handleOpenURL(_ url: URL) {}
    func sceneDidBecomeActive() {}
    func sceneWillResignActive() {}
#endif
}

#if canImport(SpotifyiOS)
extension SpotifySource: SPTAppRemoteDelegate {
    nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        Task { @MainActor in self.connectionEstablished() }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        let message = error?.localizedDescription ?? "Spotify is not running."
        Task { @MainActor in self.connectionFailed(message) }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        Task { @MainActor in self.connectionLost() }
    }
}

extension SpotifySource: SPTAppRemotePlayerStateDelegate {
    nonisolated func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        Task { @MainActor in self.handle(playerState) }
    }
}
#endif

import Foundation
import LyricCore
import MediaPlayer
import MusicKit
import UIKit

/// Reads the system Music app through `MPMusicPlayerController.systemMusicPlayer`.
///
/// `MPNowPlayingInfoCenter` only exposes *this* app's now-playing metadata, so it cannot be used to observe
/// other apps; the system music player is the supported way to follow Apple Music playback.
@MainActor
final class AppleMusicSource: NSObject, NowPlayingSource {
    let kind: PlaybackSource = .appleMusic
    var onUpdate: ((SourceUpdate) -> Void)?
    var onStatusChange: ((SourceStatus) -> Void)?
    var canSeek: Bool { true }

    private(set) var status: SourceStatus = .idle {
        didSet { if status != oldValue { onStatusChange?(status) } }
    }

    private let player = MPMusicPlayerController.systemMusicPlayer
    private var observers: [NSObjectProtocol] = []
    private var pollTask: Task<Void, Never>?
    private var isRunning = false

    private var lastItemID: MPMediaEntityPersistentID?
    private var lastTitleKey: String?
    private var lastEmittedClock: PlaybackClock?

    // MARK: NowPlayingSource

    func start() {
        guard !isRunning else { return }
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized:
            begin()
        case .notDetermined:
            status = .needsPermission
        default:
            status = .unavailable(String(localized: "Media & Apple Music access is turned off in Settings."))
        }
    }

    func stop() {
        isRunning = false
        pollTask?.cancel()
        pollTask = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        player.endGeneratingPlaybackNotifications()
        lastItemID = nil
        lastTitleKey = nil
        lastEmittedClock = nil
        status = .idle
    }

    func togglePlayPause() {
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
        scheduleRefresh(after: 0.15)
    }

    func skipNext() {
        player.skipToNextItem()
        scheduleRefresh(after: 0.3)
    }

    func skipPrevious() {
        if player.currentPlaybackTime > 3 {
            player.skipToBeginning()
        } else {
            player.skipToPreviousItem()
        }
        scheduleRefresh(after: 0.3)
    }

    func seek(to time: TimeInterval) {
        player.currentPlaybackTime = max(0, time)
        scheduleRefresh(after: 0.15)
    }

    // MARK: Permission

    /// Requests media library access (needed by the system music player) and MusicKit authorization.
    func requestAccess() async {
        _ = await withCheckedContinuation { (continuation: CheckedContinuation<MPMediaLibraryAuthorizationStatus, Never>) in
            MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
        }
        _ = await MusicAuthorization.request()
        if MPMediaLibrary.authorizationStatus() == .authorized {
            begin()
        } else {
            status = .unavailable(String(localized: "Media & Apple Music access is turned off in Settings."))
        }
    }

    // MARK: Internals

    private func begin() {
        guard !isRunning else { return }
        isRunning = true
        status = .connected
        player.beginGeneratingPlaybackNotifications()

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh(force: true) }
        })
        observers.append(center.addObserver(forName: .MPMusicPlayerControllerPlaybackStateDidChange, object: player, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh(force: false) }
        })

        refresh(force: true)

        // There is no notification for scrubbing, so poll cheaply to catch seeks and drift.
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.refresh(force: false)
            }
        }
    }

    private func scheduleRefresh(after delay: TimeInterval) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.refresh(force: false)
        }
    }

    private func refresh(force: Bool) {
        guard isRunning else { return }
        let item = player.nowPlayingItem
        let isPlaying = player.playbackState == .playing
        var position = player.currentPlaybackTime
        if !position.isFinite || position < 0 { position = 0 }
        let now = Date()

        guard let item else {
            if lastItemID != nil || lastTitleKey != nil || force {
                lastItemID = nil
                lastTitleKey = nil
                lastEmittedClock = nil
                onUpdate?(SourceUpdate(track: nil, isPlaying: false, position: 0, artwork: nil, timestamp: now))
            }
            return
        }

        let title = item.title ?? ""
        let artist = item.artist ?? item.albumArtist ?? ""
        let titleKey = "\(title)|\(artist)"
        let itemChanged = item.persistentID != lastItemID || titleKey != lastTitleKey

        let clock = PlaybackClock(anchorPosition: position, anchorDate: now, rate: isPlaying ? 1 : 0, duration: item.playbackDuration > 0 ? item.playbackDuration : nil)
        if !force, !itemChanged, let last = lastEmittedClock, last.isEquivalent(to: clock, at: now, tolerance: 0.8) {
            return
        }

        lastItemID = item.persistentID
        lastTitleKey = titleKey
        lastEmittedClock = clock

        let track = TrackInfo(
            title: title,
            artist: artist,
            album: item.albumTitle,
            duration: item.playbackDuration > 0 ? item.playbackDuration : nil,
            source: .appleMusic,
            externalID: item.playbackStoreID.isEmpty || item.playbackStoreID == "0" ? nil : item.playbackStoreID
        )
        let artwork = itemChanged ? item.artwork?.image(at: CGSize(width: 600, height: 600)) : nil
        onUpdate?(SourceUpdate(track: track, isPlaying: isPlaying, position: position, artwork: artwork, timestamp: now))
    }
}

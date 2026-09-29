import Foundation
import LyricCore
import MusicKit
import ShazamKit
import UIKit

/// Identifies whatever is playing nearby (any app, web page, radio, a speaker) with `SHManagedSession` and
/// starts lyrics from the matched offset.
///
/// The session is re-run when the song is expected to end, or every 45 s when the length is unknown, so lyrics follow
/// track changes without keeping the microphone open all the time.
@MainActor
final class ShazamSource: NowPlayingSource {
    let kind: PlaybackSource = .shazam
    var onUpdate: ((SourceUpdate) -> Void)?
    var onStatusChange: ((SourceStatus) -> Void)?

    private(set) var status: SourceStatus = .idle {
        didSet { if status != oldValue { onStatusChange?(status) } }
    }

    private var session: SHManagedSession?
    private var loopTask: Task<Void, Never>?
    private var lastTrackKey: String?

    private enum Outcome {
        case matched(nextCheck: TimeInterval)
        case noMatch
        case failed(String)
    }

    func start() {
        guard loopTask == nil else { return }
        status = .listening
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let outcome = await self.identifyOnce()
                if Task.isCancelled { return }
                switch outcome {
                case .matched(let next):
                    self.status = .listening
                    try? await Task.sleep(nanoseconds: UInt64(next * 1_000_000_000))
                case .noMatch:
                    self.status = .listening
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                case .failed(let message):
                    self.status = .unavailable(message)
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    self.status = .listening
                }
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        session?.cancel()
        session = nil
        lastTrackKey = nil
        status = .idle
    }

    /// Forces a fresh identification right now (Home screen "Listen again").
    func listenAgain() {
        stop()
        start()
    }

    private func identifyOnce() async -> Outcome {
        let session = SHManagedSession()
        self.session = session
        await session.prepare()
        let result = await session.result()

        switch result {
        case .match(let match):
            guard let item = match.mediaItems.first else { return .noMatch }
            let matchedAt = Date()
            let offset = max(0, item.predictedCurrentMatchOffset)

            var track = TrackInfo(
                title: item.title ?? "",
                artist: item.artist ?? "",
                album: nil,
                duration: nil,
                source: .shazam,
                externalID: item.appleMusicID ?? item.shazamID,
                artworkURL: item.artworkURL
            )
            await enrich(&track, appleMusicID: item.appleMusicID)

            let isNewTrack = track.key != lastTrackKey
            lastTrackKey = track.key
            let artwork = isNewTrack ? await downloadArtwork(item.artworkURL) : nil

            onUpdate?(SourceUpdate(track: track, isPlaying: true, position: offset, artwork: artwork, timestamp: matchedAt))

            let remaining = track.duration.map { $0 - offset + 2 } ?? 45
            return .matched(nextCheck: min(max(remaining, 15), 240))
        case .noMatch:
            return .noMatch
        case .error(let error, _):
            if error is CancellationError { return .noMatch }
            return .failed(error.localizedDescription)
        }
    }

    /// The song length is needed for accurate LRCLIB lookups; ShazamKit does not return it, Apple Music's catalog does.
    private func enrich(_ track: inout TrackInfo, appleMusicID: String?) async {
        guard let appleMusicID, MusicAuthorization.currentStatus == .authorized else { return }
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(appleMusicID))
        guard let song = try? await request.response().items.first else { return }
        track.duration = song.duration
        track.album = song.albumTitle
    }

    private func downloadArtwork(_ url: URL?) async -> UIImage? {
        guard let url, let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}

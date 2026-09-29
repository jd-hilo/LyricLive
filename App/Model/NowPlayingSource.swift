import Foundation
import LyricCore
import UIKit

/// A snapshot of what one music source is doing right now.
struct SourceUpdate {
    /// nil when the source has nothing loaded.
    var track: TrackInfo?
    var isPlaying: Bool
    /// Playback position in seconds at `timestamp`.
    var position: TimeInterval
    var artwork: UIImage?
    var timestamp: Date = Date()
}

enum SourceStatus: Equatable {
    case idle
    case needsPermission
    case connecting
    case connected
    case listening
    case unavailable(String)
}

@MainActor
protocol NowPlayingSource: AnyObject {
    var kind: PlaybackSource { get }
    var status: SourceStatus { get }
    var onUpdate: ((SourceUpdate) -> Void)? { get set }
    var onStatusChange: ((SourceStatus) -> Void)? { get set }
    /// Whether tapping a lyric line can move the playhead.
    var canSeek: Bool { get }

    func start()
    func stop()
    func togglePlayPause()
    func skipNext()
    func skipPrevious()
    func seek(to time: TimeInterval)
}

extension NowPlayingSource {
    var canSeek: Bool { false }
    func togglePlayPause() {}
    func skipNext() {}
    func skipPrevious() {}
    func seek(to time: TimeInterval) {}
}

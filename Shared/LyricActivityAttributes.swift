import ActivityKit
import Foundation

struct LyricActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var artist: String
        var previousLine: String?
        var currentLine: String?
        var currentTranslation: String?
        var nextLine: String?
        var nextTranslation: String?
        var isPlaying: Bool
        /// Playback position (seconds) at `updatedAt`.
        var position: Double
        var duration: Double
        var updatedAt: Date
        var paletteHex: [String]
        /// Bumped whenever the artwork file in the App Group changes, forcing a re-render.
        var artworkToken: Int
        var showsTranslation: Bool

        /// Wall-clock range for `ProgressView(timerInterval:)` while playing, so the bar advances with no updates.
        var progressRange: ClosedRange<Date>? {
            guard isPlaying, duration > 0 else { return nil }
            let start = updatedAt.addingTimeInterval(-position)
            let end = start.addingTimeInterval(duration)
            guard end > start else { return nil }
            return start...end
        }

        var progressFraction: Double {
            duration > 0 ? min(max(position / duration, 0), 1) : 0
        }
    }

    var startedAt: Date
}

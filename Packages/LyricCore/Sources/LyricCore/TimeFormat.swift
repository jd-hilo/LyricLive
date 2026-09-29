import Foundation

public enum TimeFormat {
    /// `3:07`, or `1:02:03` for long tracks.
    public static func clock(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(max(0, seconds).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// `-2:48` style remaining time.
    public static func remaining(position: TimeInterval, duration: TimeInterval) -> String {
        "-" + clock(max(0, duration - position))
    }
}

import Foundation

/// Extrapolates the playback position between updates from a music source, so UI and
/// scheduled lyric changes can be computed without polling the player.
public struct PlaybackClock: Equatable, Codable, Sendable {
    public var anchorPosition: TimeInterval
    public var anchorDate: Date
    /// 1.0 when playing at normal speed, 0 when paused.
    public var rate: Double
    public var duration: TimeInterval?

    public init(anchorPosition: TimeInterval, anchorDate: Date = Date(), rate: Double, duration: TimeInterval? = nil) {
        self.anchorPosition = anchorPosition
        self.anchorDate = anchorDate
        self.rate = rate
        self.duration = duration
    }

    public static let stopped = PlaybackClock(anchorPosition: 0, anchorDate: Date(timeIntervalSince1970: 0), rate: 0)

    public var isPlaying: Bool { rate > 0 }

    public func position(at date: Date = Date()) -> TimeInterval {
        let elapsed = max(0, date.timeIntervalSince(anchorDate)) * rate
        var value = anchorPosition + elapsed
        if let duration { value = min(value, duration) }
        return max(0, value)
    }

    public func seeking(to position: TimeInterval, at date: Date = Date()) -> PlaybackClock {
        PlaybackClock(anchorPosition: max(0, position), anchorDate: date, rate: rate, duration: duration)
    }

    public func paused(at date: Date = Date()) -> PlaybackClock {
        PlaybackClock(anchorPosition: position(at: date), anchorDate: date, rate: 0, duration: duration)
    }

    public func resumed(at date: Date = Date()) -> PlaybackClock {
        PlaybackClock(anchorPosition: position(at: date), anchorDate: date, rate: 1, duration: duration)
    }

    /// Date at which the clock reaches `position`, if it is running forward.
    public func date(forPosition position: TimeInterval) -> Date? {
        guard rate > 0 else { return nil }
        return anchorDate.addingTimeInterval((position - anchorPosition) / rate)
    }

    /// True when `other` describes (nearly) the same playhead, ignoring tiny jitter.
    public func isEquivalent(to other: PlaybackClock, at date: Date = Date(), tolerance: TimeInterval = 0.35) -> Bool {
        (rate > 0) == (other.rate > 0)
            && abs(position(at: date) - other.position(at: date)) <= tolerance
    }
}

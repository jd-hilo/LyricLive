import Foundation

public struct SyncState: Equatable, Sendable {
    /// Index of the line being sung, or nil before the first line.
    public var currentIndex: Int?
    /// 0...1 progress through the current line.
    public var lineProgress: Double
    /// Playback position (seconds) at which `currentIndex` next changes.
    public var nextChangePosition: TimeInterval?

    public init(currentIndex: Int?, lineProgress: Double, nextChangePosition: TimeInterval?) {
        self.currentIndex = currentIndex
        self.lineProgress = lineProgress
        self.nextChangePosition = nextChangePosition
    }
}

/// Maps a playback position to a lyric line.
///
/// `offset` is added to the playback position before looking a line up, so a positive offset makes lyrics
/// appear *earlier* (useful when a source reports its position late) and a negative offset makes them later.
public struct LyricSyncEngine: Sendable {
    public let lines: [LyricLine]
    public var offset: TimeInterval
    public var duration: TimeInterval?

    /// How long the last line is considered active when the duration is unknown.
    public static let defaultLastLineDuration: TimeInterval = 5

    public init(lines: [LyricLine], offset: TimeInterval = 0, duration: TimeInterval? = nil) {
        self.lines = lines
        self.offset = offset
        self.duration = duration
    }

    public init(document: LyricsDocument, offset: TimeInterval = 0, duration: TimeInterval? = nil) {
        self.init(lines: document.isSynced ? document.lines : [], offset: offset, duration: duration)
    }

    public func index(at position: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        let effective = position + offset
        guard effective >= lines[0].time else { return nil }

        var low = 0
        var high = lines.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lines[mid].time <= effective {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    public func state(at position: TimeInterval) -> SyncState {
        guard let index = index(at: position) else {
            let first = lines.first.map { $0.time - offset }
            return SyncState(currentIndex: nil, lineProgress: 0, nextChangePosition: first)
        }

        let effective = position + offset
        let start = lines[index].time
        let next: TimeInterval?
        if index + 1 < lines.count {
            next = lines[index + 1].time
        } else {
            next = nil
        }

        let end: TimeInterval
        if let next {
            end = next
        } else if let duration, duration + offset > start {
            end = duration + offset
        } else {
            end = start + Self.defaultLastLineDuration
        }

        let span = max(end - start, 0.001)
        let progress = min(max((effective - start) / span, 0), 1)
        return SyncState(currentIndex: index, lineProgress: progress, nextChangePosition: next.map { $0 - offset })
    }

    /// Position to seek to so that `lineIndex` becomes the active line.
    public func seekPosition(forLine lineIndex: Int) -> TimeInterval? {
        guard lines.indices.contains(lineIndex) else { return nil }
        // Land a hair inside the line so floating point never leaves us on the previous one.
        return max(0, lines[lineIndex].time - offset + 0.01)
    }

    /// Lines around `index`, clamped to the document.
    public func window(around index: Int?, before: Int, after: Int) -> [LyricLine] {
        guard !lines.isEmpty else { return [] }
        let center = index ?? -1
        let lower = max(0, center - before)
        let upper = min(lines.count - 1, max(center, -1) + after)
        guard lower <= upper else { return [] }
        return Array(lines[lower...upper])
    }
}

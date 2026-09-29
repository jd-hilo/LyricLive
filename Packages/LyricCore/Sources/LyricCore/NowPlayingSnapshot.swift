import Foundation

/// A few lyric lines around the playhead, ready to render in a widget, Live Activity or CarPlay list.
public struct LyricWindow: Equatable, Codable, Sendable {
    public struct Entry: Equatable, Codable, Hashable, Sendable {
        public var text: String
        public var translation: String?

        public init(text: String, translation: String? = nil) {
            self.text = text
            self.translation = translation
        }

        public var isGap: Bool { text.isEmpty }
    }

    public var previous: [Entry]
    public var current: Entry?
    public var upcoming: [Entry]
    public var progress: Double
    public var position: TimeInterval
    public var currentIndex: Int?

    public init(
        previous: [Entry] = [],
        current: Entry? = nil,
        upcoming: [Entry] = [],
        progress: Double = 0,
        position: TimeInterval = 0,
        currentIndex: Int? = nil
    ) {
        self.previous = previous
        self.current = current
        self.upcoming = upcoming
        self.progress = progress
        self.position = position
        self.currentIndex = currentIndex
    }

    public static let empty = LyricWindow()
}

/// Everything the widget, Live Activity and CarPlay extensions need to render the current song. The
/// app writes this into the App Group container whenever the song, playback state, lyrics or
/// translations change; consumers extrapolate with the embedded clock.
public struct NowPlayingSnapshot: Codable, Equatable, Sendable {
    public var track: TrackInfo?
    public var clock: PlaybackClock
    public var lines: [LyricLine]
    public var isSynced: Bool
    public var translations: [String]?
    public var offset: TimeInterval
    public var paletteHex: [String]
    public var isPro: Bool
    public var updatedAt: Date

    public init(
        track: TrackInfo? = nil,
        clock: PlaybackClock = .stopped,
        lines: [LyricLine] = [],
        isSynced: Bool = false,
        translations: [String]? = nil,
        offset: TimeInterval = 0,
        paletteHex: [String] = [],
        isPro: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.track = track
        self.clock = clock
        self.lines = lines
        self.isSynced = isSynced
        self.translations = translations
        self.offset = offset
        self.paletteHex = paletteHex
        self.isPro = isPro
        self.updatedAt = updatedAt
    }

    public static let empty = NowPlayingSnapshot()

    public var hasTrack: Bool { track != nil }

    private var engine: LyricSyncEngine {
        LyricSyncEngine(lines: isSynced ? lines : [], offset: offset, duration: clock.duration)
    }

    private func entry(at index: Int) -> LyricWindow.Entry {
        let translation = translations.flatMap { $0.indices.contains(index) ? $0[index] : nil }
        return LyricWindow.Entry(
            text: lines[index].text,
            translation: (translation?.isEmpty ?? true) ? nil : translation
        )
    }

    public func window(at date: Date = Date(), before: Int = 1, after: Int = 2) -> LyricWindow {
        let position = clock.position(at: date)
        guard isSynced, !lines.isEmpty else {
            return LyricWindow(position: position)
        }
        let state = engine.state(at: position)
        let current = state.currentIndex
        let previousRange: [Int]
        let upcomingStart: Int
        if let current {
            previousRange = Array(max(0, current - before)..<current)
            upcomingStart = current + 1
        } else {
            previousRange = []
            upcomingStart = 0
        }
        let upcomingRange = upcomingStart < lines.count
            ? Array(upcomingStart..<min(lines.count, upcomingStart + after))
            : []

        return LyricWindow(
            previous: previousRange.map(entry(at:)),
            current: current.map(entry(at:)),
            upcoming: upcomingRange.map(entry(at:)),
            progress: state.lineProgress,
            position: position,
            currentIndex: current
        )
    }

    /// Wall-clock dates at which the highlighted line changes, starting with `date` itself. Used to build
    /// a WidgetKit timeline that advances without the app being alive.
    public func changeDates(from date: Date = Date(), limit: Int = 60) -> [Date] {
        var dates = [date]
        guard clock.isPlaying, isSynced, !lines.isEmpty else { return dates }
        var position = clock.position(at: date)
        while dates.count < limit {
            guard let next = engine.state(at: position).nextChangePosition,
                  next > position - 0.0001 else { break }
            if let duration = clock.duration, next >= duration { break }
            guard let when = clock.date(forPosition: next), when > dates[dates.count - 1] else {
                position = next + 0.05
                continue
            }
            dates.append(when)
            position = next + 0.05
        }
        return dates
    }
}

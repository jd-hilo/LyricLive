import Foundation

/// Where the currently playing song is coming from.
public enum PlaybackSource: String, Codable, CaseIterable, Sendable, Identifiable {
    case appleMusic
    case spotify
    case shazam
    case demo

    public var id: String { rawValue }
}

/// Identity of a song, independent of where it is played.
public struct TrackInfo: Codable, Hashable, Sendable, Identifiable {
    public var title: String
    public var artist: String
    public var album: String?
    public var duration: TimeInterval?
    public var source: PlaybackSource
    /// Store / catalogue identifier from the source (Apple Music store ID, Spotify URI, Shazam ID).
    public var externalID: String?
    public var artworkURL: URL?

    public init(
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval? = nil,
        source: PlaybackSource,
        externalID: String? = nil,
        artworkURL: URL? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.source = source
        self.externalID = externalID
        self.artworkURL = artworkURL
    }

    /// Stable cache key. Deliberately ignores album, duration and source so the same song
    /// resolves to the same cached lyrics whichever app reports it.
    public var key: String { TrackKey.make(title: title, artist: artist) }
    public var id: String { key }
}

public struct LyricLine: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    /// Start time in seconds. Always 0 for unsynced documents.
    public var time: TimeInterval
    public var text: String

    public init(id: Int, time: TimeInterval, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }

    /// Instrumental break / stanza gap.
    public var isGap: Bool { text.isEmpty }
}

public enum LyricsOrigin: String, Codable, Sendable {
    case lrclibSynced
    case lrclibPlain
    case instrumental
    case notFound
    case bundled
    case manual
}

public struct LyricsDocument: Codable, Hashable, Sendable {
    public var lines: [LyricLine]
    public var isSynced: Bool
    public var origin: LyricsOrigin
    public var metadata: [String: String]
    public var fetchedAt: Date

    public init(
        lines: [LyricLine],
        isSynced: Bool,
        origin: LyricsOrigin = .manual,
        metadata: [String: String] = [:],
        fetchedAt: Date = Date()
    ) {
        self.lines = lines
        self.isSynced = isSynced
        self.origin = origin
        self.metadata = metadata
        self.fetchedAt = fetchedAt
    }

    public static func empty(origin: LyricsOrigin, at date: Date = Date()) -> LyricsDocument {
        LyricsDocument(lines: [], isSynced: false, origin: origin, fetchedAt: date)
    }

    public var isEmpty: Bool { lines.isEmpty }

    /// Lines with text, without instrumental gaps.
    public var textLines: [LyricLine] { lines.filter { !$0.isGap } }

    public var plainText: String {
        lines.map(\.text).joined(separator: "\n")
    }
}

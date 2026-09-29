import Foundation

public enum LyricsResult: Equatable, Sendable {
    case found(LyricsDocument)
    case instrumental
    case notFound
    /// Network or server trouble. Not cached, so the caller may retry.
    case failed(String)

    public var document: LyricsDocument? {
        if case .found(let document) = self { return document }
        return nil
    }
}

/// Resolves lyrics for a track: cache → LRCLIB exact lookup → LRCLIB search, preferring time-synced lyrics
/// and falling back to plain text.
public actor LyricsRepository {
    private let client: LRCLibClient
    private let cache: LyricsCaching
    private let now: @Sendable () -> Date

    /// A "no lyrics" answer is remembered for this long before LRCLIB is asked again.
    public static let negativeCacheLifetime: TimeInterval = 6 * 3600

    public init(client: LRCLibClient = LRCLibClient(), cache: LyricsCaching, now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.cache = cache
        self.now = now
    }

    public func lyrics(for track: TrackInfo, forceRefresh: Bool = false) async -> LyricsResult {
        let key = track.key
        if !forceRefresh, let cached = cache.document(forKey: key), let result = interpret(cached) {
            return result
        }

        do {
            let record = try await lookup(track)
            let document = makeDocument(from: record)
            cache.store(document, forKey: key)
            return interpret(document) ?? .notFound
        } catch is CancellationError {
            return .failed("cancelled")
        } catch {
            return .failed(String(describing: error))
        }
    }

    /// Stores lyrics the user picked manually (search screen) for `track`.
    public func adopt(record: LRCLibRecord, for track: TrackInfo) -> LyricsResult {
        let document = makeDocument(from: record)
        cache.remove(forKey: track.key)
        cache.store(document, forKey: track.key)
        return interpret(document) ?? .notFound
    }

    public func search(query: String) async throws -> [LRCLibRecord] {
        try await client.search(title: nil, artist: nil, query: query)
    }

    // MARK: -

    private func lookup(_ track: TrackInfo) async throws -> LRCLibRecord? {
        let title = TrackKey.cleanTitle(track.title)
        let artist = TrackKey.cleanArtist(track.artist)

        if let duration = track.duration, duration > 0 {
            if let exact = try await client.get(title: track.title, artist: track.artist, album: track.album, duration: duration),
               exact.hasSyncedLyrics || exact.hasPlainLyrics || exact.instrumental == true {
                return exact
            }
            // The cleaned signature often hits when the store title carries "(Remastered)" noise.
            if title != track.title || artist != track.artist,
               let cleaned = try await client.get(title: title, artist: artist, album: track.album, duration: duration),
               cleaned.hasSyncedLyrics || cleaned.hasPlainLyrics {
                return cleaned
            }
        }

        var candidates = try await client.search(title: title, artist: artist)
        if candidates.isEmpty {
            candidates = try await client.search(title: nil, artist: nil, query: "\(artist) \(title)")
        }
        return LRCLibMatcher.bestMatch(in: candidates, title: title, artist: artist, duration: track.duration)
    }

    private func makeDocument(from record: LRCLibRecord?) -> LyricsDocument {
        let date = now()
        guard let record else { return .empty(origin: .notFound, at: date) }
        if record.instrumental == true && !record.hasSyncedLyrics && !record.hasPlainLyrics {
            return .empty(origin: .instrumental, at: date)
        }
        if record.hasSyncedLyrics, let synced = record.syncedLyrics {
            var document = LRCParser.parse(synced, origin: .lrclibSynced)
            if document.isSynced && !document.isEmpty {
                document.fetchedAt = date
                return document
            }
        }
        if record.hasPlainLyrics, let plain = record.plainLyrics {
            var document = LRCParser.parsePlain(plain, origin: .lrclibPlain)
            document.fetchedAt = date
            if !document.isEmpty { return document }
        }
        return .empty(origin: .notFound, at: date)
    }

    private func interpret(_ document: LyricsDocument) -> LyricsResult? {
        switch document.origin {
        case .instrumental:
            return .instrumental
        case .notFound:
            // Expired negative entries are treated as a miss so we try again.
            return now().timeIntervalSince(document.fetchedAt) < Self.negativeCacheLifetime ? .notFound : nil
        default:
            return document.isEmpty ? nil : .found(document)
        }
    }
}

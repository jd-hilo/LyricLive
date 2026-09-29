import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HTTPFetching: Sendable {
    func fetch(_ request: URLRequest) async throws -> (Data, Int)
}

public struct URLSessionFetcher: HTTPFetching, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, status)
    }
}

public struct LRCLibRecord: Codable, Equatable, Sendable {
    public var id: Int?
    public var trackName: String?
    public var artistName: String?
    public var albumName: String?
    public var duration: Double?
    public var instrumental: Bool?
    public var plainLyrics: String?
    public var syncedLyrics: String?

    public init(
        id: Int? = nil,
        trackName: String? = nil,
        artistName: String? = nil,
        albumName: String? = nil,
        duration: Double? = nil,
        instrumental: Bool? = nil,
        plainLyrics: String? = nil,
        syncedLyrics: String? = nil
    ) {
        self.id = id
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.instrumental = instrumental
        self.plainLyrics = plainLyrics
        self.syncedLyrics = syncedLyrics
    }

    public var hasSyncedLyrics: Bool {
        !(syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    public var hasPlainLyrics: Bool {
        !(plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}

public enum LRCLibError: Error, Equatable, Sendable {
    case badStatus(Int)
    case invalidURL
    case decoding
}

/// Minimal client for https://lrclib.net/api (free, no API key).
public struct LRCLibClient: Sendable {
    public static let defaultBaseURL = URL(string: "https://lrclib.net/api")!

    public var baseURL: URL
    public var userAgent: String
    private let fetcher: HTTPFetching

    public init(
        baseURL: URL = LRCLibClient.defaultBaseURL,
        userAgent: String = "LyricLive/1.0 (https://github.com/example/lyriclive)",
        fetcher: HTTPFetching = URLSessionFetcher()
    ) {
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.fetcher = fetcher
    }

    /// Exact signature lookup. Returns nil when LRCLIB has no record (HTTP 404).
    public func get(title: String, artist: String, album: String?, duration: TimeInterval?) async throws -> LRCLibRecord? {
        var items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        if let album, !album.isEmpty { items.append(URLQueryItem(name: "album_name", value: album)) }
        if let duration, duration > 0 {
            items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        let (data, status) = try await fetcher.fetch(try request(path: "get", items: items))
        if status == 404 { return nil }
        guard (200..<300).contains(status) else { throw LRCLibError.badStatus(status) }
        do {
            return try JSONDecoder().decode(LRCLibRecord.self, from: data)
        } catch {
            throw LRCLibError.decoding
        }
    }

    public func search(title: String?, artist: String?, query: String? = nil) async throws -> [LRCLibRecord] {
        var items: [URLQueryItem] = []
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        if let title, !title.isEmpty { items.append(URLQueryItem(name: "track_name", value: title)) }
        if let artist, !artist.isEmpty { items.append(URLQueryItem(name: "artist_name", value: artist)) }
        guard !items.isEmpty else { return [] }
        let (data, status) = try await fetcher.fetch(try request(path: "search", items: items))
        guard (200..<300).contains(status) else { throw LRCLibError.badStatus(status) }
        do {
            return try JSONDecoder().decode([LRCLibRecord].self, from: data)
        } catch {
            throw LRCLibError.decoding
        }
    }

    private func request(path: String, items: [URLQueryItem]) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw LRCLibError.invalidURL
        }
        components.queryItems = items
        guard let url = components.url else { throw LRCLibError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        return request
    }
}

// MARK: - Ranking

public enum LRCLibMatcher {
    /// Picks the record most likely to be the requested song, preferring synced lyrics and a matching duration.
    public static func bestMatch(
        in records: [LRCLibRecord],
        title: String,
        artist: String,
        duration: TimeInterval?
    ) -> LRCLibRecord? {
        let wantedTitle = TrackKey.normalize(TrackKey.cleanTitle(title))
        let wantedArtist = TrackKey.normalize(TrackKey.cleanArtist(artist))

        var best: (record: LRCLibRecord, score: Double)?
        for record in records {
            let score = score(record, wantedTitle: wantedTitle, wantedArtist: wantedArtist, duration: duration)
            guard score >= 3 else { continue }
            if best == nil || score > best!.score {
                best = (record, score)
            }
        }
        return best?.record
    }

    static func score(_ record: LRCLibRecord, wantedTitle: String, wantedArtist: String, duration: TimeInterval?) -> Double {
        var score = 0.0
        let title = TrackKey.normalize(TrackKey.cleanTitle(record.trackName ?? ""))
        let artist = TrackKey.normalize(TrackKey.cleanArtist(record.artistName ?? ""))

        if !wantedTitle.isEmpty {
            if title == wantedTitle {
                score += 3
            } else if title.contains(wantedTitle) || wantedTitle.contains(title), !title.isEmpty {
                score += 1
            } else {
                score -= 4
            }
        }
        if !wantedArtist.isEmpty {
            if artist == wantedArtist {
                score += 2
            } else if artist.contains(wantedArtist) || wantedArtist.contains(artist), !artist.isEmpty {
                score += 1
            }
        }
        if let duration, let recordDuration = record.duration, recordDuration > 0 {
            let delta = abs(duration - recordDuration)
            if delta <= 2 {
                score += 3
            } else if delta <= 5 {
                score += 1
            } else if delta > 10 {
                score -= 3
            }
        }
        if record.hasSyncedLyrics { score += 2 }
        if record.instrumental == true { score -= 1 }
        return score
    }
}

import XCTest
@testable import LyricCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MockFetcher: HTTPFetching, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (Data, Int)
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    private let handler: Handler

    init(handler: @escaping Handler) { self.handler = handler }

    var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return _requests }

    func fetch(_ request: URLRequest) async throws -> (Data, Int) {
        record(request)
        return try handler(request)
    }

    private func record(_ request: URLRequest) {
        lock.lock(); defer { lock.unlock() }
        _requests.append(request)
    }
}

private func json(_ object: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: object)
}

final class LRCLibClientTests: XCTestCase {
    func testGetBuildsExpectedRequest() async throws {
        let fetcher = MockFetcher { _ in
            (json(["id": 1, "trackName": "Song", "artistName": "Artist", "duration": 100.0, "syncedLyrics": "[00:01.00]Hi"]), 200)
        }
        let client = LRCLibClient(fetcher: fetcher)
        let record = try await client.get(title: "Song & Co", artist: "Artist", album: "Album", duration: 99.6)
        XCTAssertEqual(record?.syncedLyrics, "[00:01.00]Hi")

        let url = try XCTUnwrap(fetcher.requests.first?.url)
        XCTAssertEqual(url.path, "/api/get")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.first { $0.name == "track_name" }?.value, "Song & Co")
        XCTAssertEqual(items.first { $0.name == "artist_name" }?.value, "Artist")
        XCTAssertEqual(items.first { $0.name == "album_name" }?.value, "Album")
        XCTAssertEqual(items.first { $0.name == "duration" }?.value, "100")
        XCTAssertNotNil(fetcher.requests.first?.value(forHTTPHeaderField: "User-Agent"))
    }

    func testGetReturnsNilOn404() async throws {
        let client = LRCLibClient(fetcher: MockFetcher { _ in (Data("{}".utf8), 404) })
        let record = try await client.get(title: "x", artist: "y", album: nil, duration: nil)
        XCTAssertNil(record)
    }

    func testGetThrowsOnServerError() async {
        let client = LRCLibClient(fetcher: MockFetcher { _ in (Data(), 500) })
        do {
            _ = try await client.get(title: "x", artist: "y", album: nil, duration: nil)
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? LRCLibError, .badStatus(500))
        }
    }

    func testSearchDecodesArray() async throws {
        let client = LRCLibClient(fetcher: MockFetcher { _ in
            (json([["id": 1, "trackName": "A"], ["id": 2, "trackName": "B", "instrumental": true]]), 200)
        })
        let records = try await client.search(title: "A", artist: nil)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[1].instrumental, true)
    }

    func testSearchWithoutTermsMakesNoRequest() async throws {
        let fetcher = MockFetcher { _ in (Data("[]".utf8), 200) }
        let client = LRCLibClient(fetcher: fetcher)
        let records = try await client.search(title: nil, artist: nil, query: "")
        XCTAssertTrue(records.isEmpty)
        XCTAssertTrue(fetcher.requests.isEmpty)
    }

    func testDecodingFailureIsReported() async {
        let client = LRCLibClient(fetcher: MockFetcher { _ in (Data("not json".utf8), 200) })
        do {
            _ = try await client.search(title: "a", artist: nil)
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? LRCLibError, .decoding)
        }
    }

    func testMatcherPrefersSyncedAndDurationMatch() {
        let wrongDuration = LRCLibRecord(id: 1, trackName: "Song", artistName: "Artist", duration: 300, syncedLyrics: "[00:01.00]x")
        let plainOnly = LRCLibRecord(id: 2, trackName: "Song", artistName: "Artist", duration: 200, plainLyrics: "x")
        let best = LRCLibRecord(id: 3, trackName: "Song (Remastered)", artistName: "Artist", duration: 201, syncedLyrics: "[00:01.00]x")
        let match = LRCLibMatcher.bestMatch(in: [wrongDuration, plainOnly, best], title: "Song", artist: "Artist", duration: 200)
        XCTAssertEqual(match?.id, 3)
    }

    func testMatcherRejectsUnrelatedTracks() {
        let other = LRCLibRecord(id: 1, trackName: "Completely Different", artistName: "Someone", duration: 200, syncedLyrics: "[00:01.00]x")
        XCTAssertNil(LRCLibMatcher.bestMatch(in: [other], title: "Song", artist: "Artist", duration: 200))
    }
}

final class LyricsRepositoryTests: XCTestCase {
    private let track = TrackInfo(title: "Song (Remastered 2011)", artist: "Artist feat. Guest", album: "Album", duration: 100, source: .appleMusic)

    private func repository(cache: LyricsCaching = MemoryLyricsCache(), now: @escaping @Sendable () -> Date = { Date() }, handler: @escaping MockFetcher.Handler) -> (LyricsRepository, MockFetcher, LyricsCaching) {
        let fetcher = MockFetcher(handler: handler)
        let repo = LyricsRepository(client: LRCLibClient(fetcher: fetcher), cache: cache, now: now)
        return (repo, fetcher, cache)
    }

    func testFetchesSyncedLyricsAndCaches() async {
        let (repo, fetcher, _) = repository { _ in
            (json(["id": 1, "trackName": "Song", "artistName": "Artist", "duration": 100.0, "syncedLyrics": "[00:01.00]Hi\n[00:05.00]There", "plainLyrics": "Hi\nThere"]), 200)
        }
        let first = await repo.lyrics(for: track)
        XCTAssertEqual(first.document?.lines.map(\.text), ["Hi", "There"])
        XCTAssertEqual(first.document?.isSynced, true)
        XCTAssertEqual(fetcher.requests.count, 1)

        let second = await repo.lyrics(for: track)
        XCTAssertEqual(second.document?.lines.map(\.text), ["Hi", "There"])
        XCTAssertEqual(fetcher.requests.count, 1, "second lookup must be served from the cache")
    }

    func testFallsBackToPlainLyrics() async {
        let (repo, _, _) = repository { _ in
            (json(["id": 1, "trackName": "Song", "artistName": "Artist", "duration": 100.0, "syncedLyrics": NSNull(), "plainLyrics": "One\nTwo"]), 200)
        }
        let result = await repo.lyrics(for: track)
        XCTAssertEqual(result.document?.isSynced, false)
        XCTAssertEqual(result.document?.origin, .lrclibPlain)
        XCTAssertEqual(result.document?.lines.map(\.text), ["One", "Two"])
    }

    func testFallsBackToSearchWhenExactLookupMisses() async {
        let (repo, fetcher, _) = repository { request in
            if request.url!.path.hasSuffix("/get") { return (Data("{}".utf8), 404) }
            return (json([
                ["id": 9, "trackName": "Song", "artistName": "Artist", "duration": 101.0, "syncedLyrics": "[00:02.00]Found"],
            ]), 200)
        }
        let result = await repo.lyrics(for: track)
        XCTAssertEqual(result.document?.lines.map(\.text), ["Found"])
        XCTAssertTrue(fetcher.requests.contains { $0.url!.path.hasSuffix("/search") })
    }

    func testSearchOnlyPathWhenDurationUnknown() async {
        var shazamTrack = track
        shazamTrack.duration = nil
        let (repo, fetcher, _) = repository { _ in
            (json([["id": 9, "trackName": "Song", "artistName": "Artist", "syncedLyrics": "[00:02.00]Found"]]), 200)
        }
        let result = await repo.lyrics(for: shazamTrack)
        XCTAssertNotNil(result.document)
        XCTAssertFalse(fetcher.requests.contains { $0.url!.path.hasSuffix("/get") })
    }

    func testNotFoundIsNegativeCachedThenRetriedAfterExpiry() async {
        let clock = LockedDate(Date(timeIntervalSince1970: 1000))
        let (repo, fetcher, _) = repository(now: { clock.value }) { _ in (Data("[]".utf8), 200) }
        var t = track
        t.duration = nil

        let first = await repo.lyrics(for: t)
        XCTAssertEqual(first, .notFound)
        let requestsAfterFirst = fetcher.requests.count

        _ = await repo.lyrics(for: t)
        XCTAssertEqual(fetcher.requests.count, requestsAfterFirst, "negative cache hit")

        clock.value = clock.value.addingTimeInterval(LyricsRepository.negativeCacheLifetime + 1)
        _ = await repo.lyrics(for: t)
        XCTAssertGreaterThan(fetcher.requests.count, requestsAfterFirst, "expired negative entry is retried")
    }

    func testInstrumentalIsReportedAndCached() async {
        let (repo, fetcher, _) = repository { _ in
            (json(["id": 1, "trackName": "Song", "artistName": "Artist", "duration": 100.0, "instrumental": true]), 200)
        }
        let a = await repo.lyrics(for: track)
        let b = await repo.lyrics(for: track)
        XCTAssertEqual(a, .instrumental)
        XCTAssertEqual(b, .instrumental)
        XCTAssertEqual(fetcher.requests.count, 1)
    }

    func testNetworkFailureIsNotCached() async {
        struct Offline: Error {}
        let counter = LockedCounter()
        let (repo, _, cache) = repository { _ in
            if counter.increment() == 1 { throw Offline() }
            return (json(["id": 1, "trackName": "Song", "artistName": "Artist", "duration": 100.0, "syncedLyrics": "[00:01.00]Back online"]), 200)
        }
        if case .failed = await repo.lyrics(for: track) {} else { XCTFail("expected failure") }
        XCTAssertNil(cache.document(forKey: track.key))
        let retry = await repo.lyrics(for: track)
        XCTAssertEqual(retry.document?.lines.first?.text, "Back online")
    }

    func testForceRefreshBypassesCache() async {
        let counter = LockedCounter()
        let (repo, fetcher, _) = repository { _ in
            let n = counter.increment()
            return (json(["id": n, "trackName": "Song", "artistName": "Artist", "duration": 100.0, "syncedLyrics": "[00:01.00]v\(n)"]), 200)
        }
        _ = await repo.lyrics(for: track)
        let refreshed = await repo.lyrics(for: track, forceRefresh: true)
        XCTAssertEqual(refreshed.document?.lines.first?.text, "v2")
        XCTAssertEqual(fetcher.requests.count, 2)
    }

    func testAdoptReplacesCachedLyricsAndTranslations() async {
        let cache = MemoryLyricsCache()
        let (repo, _, _) = repository(cache: cache) { _ in (Data("[]".utf8), 200) }
        cache.storeTranslations(["old"], forKey: track.key, language: "zh-Hant")
        let result = await repo.adopt(record: LRCLibRecord(id: 5, syncedLyrics: "[00:01.00]Picked"), for: track)
        XCTAssertEqual(result.document?.lines.first?.text, "Picked")
        XCTAssertNil(cache.translations(forKey: track.key, language: "zh-Hant"))
        XCTAssertEqual(cache.document(forKey: track.key)?.lines.first?.text, "Picked")
    }
}

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
}

final class LockedDate: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Date
    init(_ value: Date) { _value = value }
    var value: Date {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); _value = newValue; lock.unlock() }
    }
}

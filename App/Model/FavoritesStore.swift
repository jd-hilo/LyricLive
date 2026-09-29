import Foundation
import LyricCore

struct HistoryEntry: Codable, Identifiable, Hashable {
    var track: TrackInfo
    var playedAt: Date
    var id: String { track.key }
}

/// Favorites (heart button) and recently played songs, stored as JSON in the App Group container.
@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favorites: [TrackInfo] = []
    @Published private(set) var history: [HistoryEntry] = []

    private let maxHistory = 60
    private let favoritesURL: URL
    private let historyURL: URL

    init(directory: URL = AppGroup.containerURL) {
        favoritesURL = directory.appendingPathComponent("favorites.json")
        historyURL = directory.appendingPathComponent("history.json")
        favorites = Self.load([TrackInfo].self, from: favoritesURL) ?? []
        history = Self.load([HistoryEntry].self, from: historyURL) ?? []
    }

    func isFavorite(_ track: TrackInfo?) -> Bool {
        guard let track else { return false }
        return favorites.contains { $0.key == track.key }
    }

    func toggleFavorite(_ track: TrackInfo) {
        if let index = favorites.firstIndex(where: { $0.key == track.key }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(track, at: 0)
        }
        Self.save(favorites, to: favoritesURL)
    }

    func recordPlay(_ track: TrackInfo) {
        history.removeAll { $0.track.key == track.key }
        history.insert(HistoryEntry(track: track, playedAt: Date()), at: 0)
        if history.count > maxHistory { history.removeLast(history.count - maxHistory) }
        Self.save(history, to: historyURL)
    }

    func clearHistory() {
        history = []
        Self.save(history, to: historyURL)
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

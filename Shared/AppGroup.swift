import Foundation
import LyricCore
import UIKit

/// Values injected through Info.plist (see `project.yml`), so renaming the app is a one-line change.
enum AppGroup {
    static var identifier: String {
        (Bundle.main.object(forInfoDictionaryKey: "LLAppGroup") as? String) ?? "group.com.example.lyriclive"
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.temporaryDirectory
    }

    static var urlScheme: String {
        (Bundle.main.object(forInfoDictionaryKey: "LLURLScheme") as? String) ?? "lyriclive"
    }
}

/// Now-playing state shared from the app to widgets and the Live Activity through the App Group container.
enum SharedStore {
    private static var snapshotURL: URL {
        AppGroup.containerURL.appendingPathComponent("now-playing.json")
    }

    static var artworkURL: URL {
        AppGroup.containerURL.appendingPathComponent("artwork.jpg")
    }

    static func write(_ snapshot: NowPlayingSnapshot) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    static func read() -> NowPlayingSnapshot {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(NowPlayingSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func writeArtwork(_ data: Data?) {
        if let data {
            try? data.write(to: artworkURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: artworkURL)
        }
    }

    static func loadArtwork() -> UIImage? {
        guard let data = try? Data(contentsOf: artworkURL) else { return nil }
        return UIImage(data: data)
    }
}

extension Notification.Name {
    /// Posted by `AppModel` whenever lyrics, the current line or playback state changed.
    static let lyricStateDidChange = Notification.Name("LyricStateDidChange")
}

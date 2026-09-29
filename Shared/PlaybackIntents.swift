import AppIntents
import Foundation

enum PlaybackCommand: String, Sendable {
    case togglePlayPause
    case next
    case previous
    case toggleTranslation
}

/// Bridge between App Intents and the music sources. Only the app process installs a handler; intents
/// conforming to `LiveActivityIntent` / `AudioPlaybackIntent` are executed by the system in the app process.
@MainActor
final class PlaybackCommandBus {
    static let shared = PlaybackCommandBus()
    var handler: ((PlaybackCommand) -> Void)?

    func send(_ command: PlaybackCommand) {
        handler?(command)
    }
}

// MARK: - Live Activity buttons

struct PlayPauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Play or Pause"
    static var isDiscoverable: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        PlaybackCommandBus.shared.send(.togglePlayPause)
        return .result()
    }
}

struct NextTrackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Next Song"
    static var isDiscoverable: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        PlaybackCommandBus.shared.send(.next)
        return .result()
    }
}

struct PreviousTrackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Previous Song"
    static var isDiscoverable: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        PlaybackCommandBus.shared.send(.previous)
        return .result()
    }
}

// MARK: - Home Screen widget buttons

struct WidgetPlayPauseIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play or Pause"
    static var isDiscoverable: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        PlaybackCommandBus.shared.send(.togglePlayPause)
        return .result()
    }
}

struct WidgetNextTrackIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Next Song"
    static var isDiscoverable: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        PlaybackCommandBus.shared.send(.next)
        return .result()
    }
}

struct WidgetPreviousTrackIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Previous Song"
    static var isDiscoverable: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        PlaybackCommandBus.shared.send(.previous)
        return .result()
    }
}

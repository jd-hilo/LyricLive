import Combine
import Foundation
import LyricCore
import SwiftUI

enum LyricAlignment: String, CaseIterable, Identifiable {
    case leading, center, trailing

    var id: String { rawValue }

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frame: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var text: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var unit: UnitPoint {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .leading: return "Left"
        case .center: return "Center"
        case .trailing: return "Right"
        }
    }

    var symbol: String {
        switch self {
        case .leading: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .trailing: return "text.alignright"
        }
    }
}

enum LyricBackgroundStyle: String, CaseIterable, Identifiable {
    case animatedGradient, artworkBlur, solid, black

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .animatedGradient: return "Animated gradient"
        case .artworkBlur: return "Artwork blur"
        case .solid: return "Solid color"
        case .black: return "Black"
        }
    }

    var requiresPro: Bool { self == .artworkBlur }
}

enum LyricFontStyle: String, CaseIterable, Identifiable {
    case system, rounded, serif, monospaced

    var id: String { rawValue }

    var design: Font.Design {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .monospaced: return "Monospaced"
        }
    }

    var requiresPro: Bool { self != .system }
}

/// User preferences, persisted in the App Group defaults.
@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var fontScale: Double { didSet { defaults.set(fontScale, forKey: Keys.fontScale) } }
    @Published var alignment: LyricAlignment { didSet { defaults.set(alignment.rawValue, forKey: Keys.alignment) } }
    @Published var backgroundStyle: LyricBackgroundStyle { didSet { defaults.set(backgroundStyle.rawValue, forKey: Keys.background) } }
    @Published var fontStyle: LyricFontStyle { didSet { defaults.set(fontStyle.rawValue, forKey: Keys.fontStyle) } }

    @Published var showTranslation: Bool { didSet { defaults.set(showTranslation, forKey: Keys.showTranslation) } }
    @Published var translationLanguage: String { didSet { defaults.set(translationLanguage, forKey: Keys.translationLanguage) } }

    /// Global lyric offset in milliseconds (positive = lyrics appear earlier).
    @Published var globalOffsetMs: Int { didSet { defaults.set(globalOffsetMs, forKey: Keys.globalOffset) } }
    @Published private(set) var trackOffsetsMs: [String: Int] { didSet { saveOffsets() } }

    @Published var appleMusicEnabled: Bool { didSet { defaults.set(appleMusicEnabled, forKey: Keys.appleMusic) } }
    @Published var spotifyEnabled: Bool { didSet { defaults.set(spotifyEnabled, forKey: Keys.spotify) } }
    @Published var shazamEnabled: Bool { didSet { defaults.set(shazamEnabled, forKey: Keys.shazam) } }

    @Published var liveActivityEnabled: Bool { didSet { defaults.set(liveActivityEnabled, forKey: Keys.liveActivity) } }
    @Published var keepAliveInBackground: Bool { didSet { defaults.set(keepAliveInBackground, forKey: Keys.keepAlive) } }

    @Published var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) } }
    @Published var translationQuota: DailyQuota { didSet { saveQuota() } }

    private enum Keys {
        static let fontScale = "settings.fontScale"
        static let alignment = "settings.alignment"
        static let background = "settings.background"
        static let fontStyle = "settings.fontStyle"
        static let showTranslation = "settings.showTranslation"
        static let translationLanguage = "settings.translationLanguage"
        static let globalOffset = "settings.globalOffsetMs"
        static let trackOffsets = "settings.trackOffsetsMs"
        static let appleMusic = "settings.source.appleMusic"
        static let spotify = "settings.source.spotify"
        static let shazam = "settings.source.shazam"
        static let liveActivity = "settings.liveActivity"
        static let keepAlive = "settings.keepAlive"
        static let onboarding = "settings.onboardingDone"
        static let quota = "settings.translationQuota"
    }

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        func bool(_ key: String, default value: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? value : defaults.bool(forKey: key)
        }

        let scale = defaults.object(forKey: Keys.fontScale) == nil ? 1.0 : defaults.double(forKey: Keys.fontScale)
        fontScale = min(max(scale, 0.75), 1.6)
        alignment = LyricAlignment(rawValue: defaults.string(forKey: Keys.alignment) ?? "") ?? .leading
        backgroundStyle = LyricBackgroundStyle(rawValue: defaults.string(forKey: Keys.background) ?? "") ?? .animatedGradient
        fontStyle = LyricFontStyle(rawValue: defaults.string(forKey: Keys.fontStyle) ?? "") ?? .system
        showTranslation = bool(Keys.showTranslation, default: false)
        translationLanguage = defaults.string(forKey: Keys.translationLanguage) ?? TranslationLanguages.defaultTarget()
        globalOffsetMs = defaults.integer(forKey: Keys.globalOffset)
        appleMusicEnabled = bool(Keys.appleMusic, default: true)
        spotifyEnabled = bool(Keys.spotify, default: false)
        shazamEnabled = bool(Keys.shazam, default: true)
        liveActivityEnabled = bool(Keys.liveActivity, default: true)
        keepAliveInBackground = bool(Keys.keepAlive, default: false)
        hasCompletedOnboarding = bool(Keys.onboarding, default: false)

        if let data = defaults.data(forKey: Keys.trackOffsets),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            trackOffsetsMs = decoded
        } else {
            trackOffsetsMs = [:]
        }
        if let data = defaults.data(forKey: Keys.quota),
           let decoded = try? JSONDecoder().decode(DailyQuota.self, from: data) {
            translationQuota = decoded
        } else {
            translationQuota = DailyQuota()
        }
    }

    func offsetMs(for trackKey: String) -> Int {
        trackOffsetsMs[trackKey] ?? 0
    }

    func setOffsetMs(_ value: Int, for trackKey: String) {
        var updated = trackOffsetsMs
        if value == 0 {
            updated.removeValue(forKey: trackKey)
        } else {
            updated[trackKey] = value
        }
        trackOffsetsMs = updated
    }

    /// Total offset applied to the lyrics of a track, in seconds.
    func effectiveOffset(for trackKey: String?) -> TimeInterval {
        Double(globalOffsetMs + (trackKey.map(offsetMs(for:)) ?? 0)) / 1000
    }

    func resetLooks() {
        fontScale = 1
        alignment = .leading
        backgroundStyle = .animatedGradient
        fontStyle = .system
    }

    private func saveOffsets() {
        if let data = try? JSONEncoder().encode(trackOffsetsMs) {
            defaults.set(data, forKey: Keys.trackOffsets)
        }
    }

    private func saveQuota() {
        if let data = try? JSONEncoder().encode(translationQuota) {
            defaults.set(data, forKey: Keys.quota)
        }
    }
}

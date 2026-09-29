import Foundation

public enum ProFeature: String, CaseIterable, Codable, Sendable, Identifiable {
    case translation
    case liveActivity
    case largeWidgets
    case carPlay
    case spotify
    case shazam
    case shareCardsNoWatermark
    case premiumBackgrounds

    public var id: String { rawValue }
}

/// What the free tier may do. Kept in the core module so the app, widgets and tests share one rule set.
public enum ProPolicy {
    public static let freeTranslationsPerDay = 3

    public static func isAllowed(_ feature: ProFeature, isPro: Bool) -> Bool {
        if isPro { return true }
        switch feature {
        case .translation:
            // Free users get a small daily quota, checked through `DailyQuota`.
            return true
        case .liveActivity, .largeWidgets, .carPlay, .spotify, .shazam, .shareCardsNoWatermark, .premiumBackgrounds:
            return false
        }
    }
}

/// Counts uses per calendar day, used for the free translation allowance.
public struct DailyQuota: Codable, Equatable, Sendable {
    public var dayKey: String
    public var used: Int

    public init(dayKey: String = "", used: Int = 0) {
        self.dayKey = dayKey
        self.used = used
    }

    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public func remaining(limit: Int, on date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard dayKey == Self.key(for: date, calendar: calendar) else { return limit }
        return max(0, limit - used)
    }

    /// Consumes one use. Returns false, without changing state, when the day's allowance is spent.
    @discardableResult
    public mutating func consume(limit: Int, on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let today = Self.key(for: date, calendar: calendar)
        if dayKey != today {
            dayKey = today
            used = 0
        }
        guard used < limit else { return false }
        used += 1
        return true
    }
}

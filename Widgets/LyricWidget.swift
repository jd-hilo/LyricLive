import LyricCore
import SwiftUI
import WidgetKit

struct LyricEntry: TimelineEntry {
    let date: Date
    let snapshot: NowPlayingSnapshot
    let artwork: UIImage?

    /// Lines around the playhead at this entry's date. A hair is added so boundary entries land on the new line.
    var window: LyricWindow {
        snapshot.window(at: date.addingTimeInterval(0.15), before: 1, after: 3)
    }

    static var placeholder: LyricEntry {
        var snapshot = NowPlayingSnapshot(
            track: DemoContent.track,
            clock: PlaybackClock(anchorPosition: 26, anchorDate: Date(), rate: 0, duration: DemoContent.track.duration),
            lines: DemoContent.document.lines,
            isSynced: true,
            translations: DemoContent.translationsEn,
            paletteHex: PaletteExtractor.fallback.map(\.hex),
            isPro: true
        )
        snapshot.clock.rate = 0
        return LyricEntry(date: Date(), snapshot: snapshot, artwork: DemoArtworkImage.make())
    }
}

/// Small procedural artwork for widget previews.
enum DemoArtworkImage {
    static func make(size: CGFloat = 200) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let colors = [UIColor(red: 0.18, green: 0.10, blue: 0.55, alpha: 1).cgColor, UIColor(red: 0.96, green: 0.30, blue: 0.55, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])
            }
        }
    }
}

struct LyricProvider: TimelineProvider {
    func placeholder(in context: Context) -> LyricEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (LyricEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(LyricEntry(date: Date(), snapshot: SharedStore.read(), artwork: SharedStore.loadArtwork()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LyricEntry>) -> Void) {
        let snapshot = SharedStore.read()
        let artwork = SharedStore.loadArtwork()
        let now = Date()

        // One entry per lyric line change, so the widget advances on its own while the app is asleep.
        let dates = snapshot.changeDates(from: now, limit: 90)
        let entries = dates.map { LyricEntry(date: $0, snapshot: snapshot, artwork: artwork) }

        let refresh: Date
        if snapshot.clock.isPlaying, let last = dates.last {
            refresh = last.addingTimeInterval(20)
        } else {
            refresh = now.addingTimeInterval(30 * 60)
        }
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

struct LyricWidget: Widget {
    let kind = "LyricWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LyricProvider()) { entry in
            LyricWidgetView(entry: entry)
                .widgetURL(URL(string: "\(AppGroup.urlScheme)://lyrics"))
        }
        .configurationDisplayName("Lyrics")
        .description("The current lyric line, updated as the song plays.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
            .accessoryRectangular, .accessoryInline, .accessoryCircular,
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Views

struct LyricWidgetView: View {
    let entry: LyricEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .systemSmall:
            small.containerBackground(for: .widget) { WidgetBackground(entry: entry) }
        case .systemMedium:
            gated { medium }.containerBackground(for: .widget) { WidgetBackground(entry: entry) }
        default:
            gated { large(extra: family == .systemExtraLarge) }.containerBackground(for: .widget) { WidgetBackground(entry: entry) }
        }
    }

    private var window: LyricWindow { entry.window }
    private var track: TrackInfo? { entry.snapshot.track }

    /// Medium and larger sizes are a Pro feature.
    @ViewBuilder
    private func gated<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if entry.snapshot.isPro || !entry.snapshot.hasTrack {
            content()
        } else {
            ProLockedWidget()
        }
    }

    private func currentText(_ window: LyricWindow) -> String {
        guard entry.snapshot.hasTrack else { return String(localized: "Play a song to see lyrics") }
        if let current = window.current { return current.text.isEmpty ? "♪" : current.text }
        if entry.snapshot.isSynced { return window.upcoming.first?.text ?? "♪" }
        return String(localized: "No synced lyrics")
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ArtworkThumb(image: entry.artwork, cornerRadius: 8)
                    .frame(width: 30, height: 30)
                Text(track?.title ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            Text(currentText(window))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.75)
            if let next = window.upcoming.first, !next.isGap {
                Text(next.text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(14)
    }

    private var medium: some View {
        ZStack(alignment: .trailing) {
            VinylView(image: entry.artwork)
                .frame(width: 138, height: 138)
                .offset(x: 46)
                .opacity(0.95)
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note").font(.system(size: 11, weight: .bold))
                        Text(track?.title ?? "")
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(track?.artist ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    Spacer(minLength: 0)
                    Text(currentText(window))
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.75)
                    if let translation = window.current?.translation {
                        Text(translation)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    } else if let next = window.upcoming.first, !next.isGap {
                        Text(next.text)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 100)
            }
            .padding(16)
        }
    }

    private func large(extra: Bool) -> some View {
        let scale: CGFloat = extra ? 1.25 : 1
        return VStack(spacing: 12 * scale) {
            HStack(spacing: 12) {
                VinylView(image: entry.artwork)
                    .frame(width: 56 * scale, height: 56 * scale)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track?.title ?? "")
                        .font(.system(size: 16 * scale, weight: .bold))
                        .lineLimit(1)
                    Text(track?.artist ?? "")
                        .font(.system(size: 13 * scale))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
            }
            .foregroundStyle(.white)

            Spacer(minLength: 0)
            VStack(spacing: 10 * scale) {
                if let previous = window.previous.last, !previous.isGap {
                    Text(previous.text)
                        .font(.system(size: 15 * scale, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineLimit(2)
                }
                VStack(spacing: 4) {
                    Text(currentText(window))
                        .font(.system(size: 26 * scale, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    if let translation = window.current?.translation {
                        Text(translation)
                            .font(.system(size: 16 * scale, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                ForEach(Array(window.upcoming.prefix(2).enumerated()), id: \.offset) { index, next in
                    if !next.isGap {
                        Text(next.text)
                            .font(.system(size: 15 * scale, weight: .medium))
                            .foregroundStyle(.white.opacity(index == 0 ? 0.55 : 0.32))
                            .lineLimit(2)
                    }
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .padding(18 * scale)
    }

    // MARK: Lock Screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.map { "\($0.title) · \($0.artist)" } ?? String(localized: "No song playing"))
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .widgetAccentable()
            Text(currentText(window))
                .font(.system(size: 14, weight: .bold))
                .lineLimit(2)
            if let next = window.upcoming.first, !next.isGap {
                Text(next.text)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .opacity(0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }

    private var inline: some View {
        Text(currentText(window))
            .containerBackground(for: .widget) { Color.clear }
    }

    private var circular: some View {
        Gauge(value: progressFraction) {
            Image(systemName: "music.note")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .containerBackground(for: .widget) { Color.clear }
    }

    private var progressFraction: Double {
        guard let duration = entry.snapshot.clock.duration, duration > 0 else { return 0 }
        return min(max(entry.snapshot.clock.position(at: entry.date) / duration, 0), 1)
    }
}

struct WidgetBackground: View {
    let entry: LyricEntry

    var body: some View {
        let colors = gradientColors(fromHex: entry.snapshot.paletteHex)
        ZStack {
            Color(hex: "#0E0D1F")
            LinearGradient(
                colors: [(colors.first ?? Brand.violet).opacity(0.55), (colors.dropFirst().first ?? Brand.pink).opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct ProLockedWidget: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.system(size: 22))
            Text("Unlock with Pro")
                .font(.system(size: 14, weight: .bold))
            Text("Open the app to upgrade.")
                .font(.system(size: 11))
                .opacity(0.6)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

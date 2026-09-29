import AppIntents
import LyricCore
import SwiftUI
import WidgetKit

/// Album art and playback buttons on the Home Screen (added in the reference app's 1.1.0).
struct NowPlayingWidget: Widget {
    let kind = "NowPlayingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LyricProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
                .widgetURL(URL(string: "\(AppGroup.urlScheme)://lyrics"))
        }
        .configurationDisplayName("Now Playing")
        .description("Album art with playback controls.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct NowPlayingWidgetView: View {
    let entry: LyricEntry
    @Environment(\.widgetFamily) private var family

    private var track: TrackInfo? { entry.snapshot.track }
    private var isPlaying: Bool { entry.snapshot.clock.isPlaying }

    var body: some View {
        Group {
            if entry.snapshot.isPro || !entry.snapshot.hasTrack {
                content
            } else {
                ProLockedWidget()
            }
        }
        .containerBackground(for: .widget) { WidgetBackground(entry: entry) }
    }

    @ViewBuilder
    private var content: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkThumb(image: entry.artwork, cornerRadius: 12)
                    .frame(width: 64, height: 64)
                Spacer(minLength: 0)
                titleBlock
                controls(size: 16)
            }
            .padding(14)
        } else {
            HStack(spacing: 14) {
                ArtworkThumb(image: entry.artwork, cornerRadius: 16)
                    .frame(width: 112, height: 112)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                VStack(alignment: .leading, spacing: 8) {
                    titleBlock
                    Spacer(minLength: 0)
                    controls(size: 22)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track?.title ?? String(localized: "Nothing playing"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(track?.artist ?? "")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
    }

    private func controls(size: CGFloat) -> some View {
        HStack(spacing: size * 1.3) {
            Button(intent: WidgetPreviousTrackIntent()) {
                Image(systemName: "backward.fill").font(.system(size: size))
            }
            Button(intent: WidgetPlayPauseIntent()) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.system(size: size * 1.2))
            }
            Button(intent: WidgetNextTrackIntent()) {
                Image(systemName: "forward.fill").font(.system(size: size))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

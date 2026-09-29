import ActivityKit
import AppIntents
import LyricCore
import SwiftUI
import WidgetKit

/// Lock Screen Live Activity and Dynamic Island (screenshots 3 and 4 of the reference listing).
struct LyricLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricActivityAttributes.self) { context in
            LockScreenLyricView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "\(AppGroup.urlScheme)://lyrics"))
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ArtworkThumb(image: SharedStore.loadArtwork(), cornerRadius: 8)
                        .frame(width: 40, height: 40)
                        .id(state.artworkToken)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: state.isPlaying ? "waveform" : "pause.fill")
                        .symbolEffect(.variableColor.iterative, isActive: state.isPlaying)
                        .foregroundStyle(Brand.pink)
                        .frame(height: 40)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        LyricBlock(state: state, currentSize: 19, dimmedPrevious: true)
                        HStack(spacing: 44) {
                            Button(intent: PreviousTrackIntent()) { Image(systemName: "backward.fill") }
                            Button(intent: PlayPauseIntent()) {
                                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 22))
                            }
                            Button(intent: NextTrackIntent()) { Image(systemName: "forward.fill") }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                    }
                }
            } compactLeading: {
                Text(state.currentLine ?? "♪")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 84, alignment: .leading)
            } compactTrailing: {
                ArtworkThumb(image: SharedStore.loadArtwork(), cornerRadius: 5)
                    .frame(width: 22, height: 22)
                    .id(state.artworkToken)
            } minimal: {
                ArtworkThumb(image: SharedStore.loadArtwork(), cornerRadius: 11)
                    .frame(width: 22, height: 22)
                    .id(state.artworkToken)
            }
            .keylineTint(Brand.pink)
        }
    }
}

/// Previous line (dim), current line (bold) with translation, and the next line (dim).
struct LyricBlock: View {
    let state: LyricActivityAttributes.ContentState
    var currentSize: CGFloat = 17
    var dimmedPrevious = false

    var body: some View {
        VStack(spacing: 3) {
            if dimmedPrevious, let previous = state.previousLine {
                Text(previous)
                    .font(.system(size: currentSize * 0.7, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
            }
            Text(state.currentLine ?? "♪")
                .font(.system(size: currentSize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            if state.showsTranslation, let translation = state.currentTranslation {
                Text(translation)
                    .font(.system(size: currentSize * 0.74, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            if let next = state.nextLine {
                Text(next)
                    .font(.system(size: currentSize * 0.82, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

struct LockScreenLyricView: View {
    let state: LyricActivityAttributes.ContentState

    var body: some View {
        let colors = gradientColors(fromHex: state.paletteHex)
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ArtworkThumb(image: SharedStore.loadArtwork(), cornerRadius: 8)
                    .frame(width: 44, height: 44)
                    .id(state.artworkToken)
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.title)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                    Text(state.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack(spacing: 18) {
                    Button(intent: PreviousTrackIntent()) { Image(systemName: "backward.fill") }
                    Button(intent: PlayPauseIntent()) {
                        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 20))
                    }
                    Button(intent: NextTrackIntent()) { Image(systemName: "forward.fill") }
                }
                .buttonStyle(.plain)
                .font(.system(size: 16))
            }

            progress

            LyricBlock(state: state, currentSize: 17, dimmedPrevious: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [(colors.first ?? Brand.violet).opacity(0.5), (colors.dropFirst().first ?? Brand.pink).opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private var progress: some View {
        HStack(spacing: 8) {
            if let range = state.progressRange {
                Text(timerInterval: range, countsDown: false, showsHours: false)
                    .frame(width: 38, alignment: .leading)
                ProgressView(timerInterval: range, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear)
                    .tint(.white)
                HStack(spacing: 0) {
                    Text(verbatim: "-")
                    Text(timerInterval: range, countsDown: true, showsHours: false)
                }
                .frame(width: 42, alignment: .trailing)
            } else {
                Text(TimeFormat.clock(state.position))
                    .frame(width: 38, alignment: .leading)
                ProgressView(value: state.progressFraction)
                    .progressViewStyle(.linear)
                    .tint(.white)
                Text(state.duration > 0 ? TimeFormat.remaining(position: state.position, duration: state.duration) : "")
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .font(.system(size: 10, weight: .medium).monospacedDigit())
        .foregroundStyle(.white.opacity(0.65))
    }
}

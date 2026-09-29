import LyricCore
import SwiftUI

/// Progress scrubber with elapsed / remaining time. Dragging seeks when the source supports it.
struct ProgressScrubber: View {
    @EnvironmentObject private var model: AppModel

    @State private var dragFraction: Double?

    var body: some View {
        let duration = model.track?.duration ?? 0
        VStack(spacing: 6) {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let position = model.clock.position(at: context.date)
                let fraction = duration > 0 ? min(max((dragFraction ?? position / duration), 0), 1) : 0
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(.white)
                            .frame(width: proxy.size.width * fraction)
                    }
                    .frame(height: dragFraction == nil ? 5 : 9)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard model.canSeek, duration > 0 else { return }
                                dragFraction = min(max(value.location.x / proxy.size.width, 0), 1)
                            }
                            .onEnded { value in
                                defer { dragFraction = nil }
                                guard model.canSeek, duration > 0 else { return }
                                let target = min(max(value.location.x / proxy.size.width, 0), 1) * duration
                                model.seek(to: target)
                            }
                    )
                    .animation(.easeOut(duration: 0.15), value: dragFraction == nil)
                }
                .frame(height: 20)

                HStack {
                    Text(TimeFormat.clock(dragFraction.map { $0 * duration } ?? position))
                    Spacer()
                    Text(duration > 0 ? TimeFormat.remaining(position: dragFraction.map { $0 * duration } ?? position, duration: duration) : "")
                }
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.65))
            }
        }
    }
}

/// Previous / play-pause / next.
struct TransportControls: View {
    @EnvironmentObject private var model: AppModel
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 26 : 38) {
            Button { model.skipPrevious() } label: {
                Image(systemName: "backward.fill").font(.system(size: compact ? 22 : 26))
            }
            .accessibilityLabel(Text("Previous song"))

            Button { model.togglePlayPause() } label: {
                Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: compact ? 52 : 64))
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel(Text(model.isPlaying ? "Pause" : "Play"))

            Button { model.skipNext() } label: {
                Image(systemName: "forward.fill").font(.system(size: compact ? 22 : 26))
            }
            .accessibilityLabel(Text("Next song"))
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }
}

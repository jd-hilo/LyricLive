import LyricCore
import SwiftUI

/// Blurred, slowly drifting gradient built from the artwork palette (screenshot 2 of the reference listing).
struct LyricBackground: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: StoreManager

    private var style: LyricBackgroundStyle {
        settings.backgroundStyle.requiresPro && !store.isPro ? .animatedGradient : settings.backgroundStyle
    }

    private var colors: [Color] {
        model.palette.map { Color($0) }
    }

    var body: some View {
        ZStack {
            switch style {
            case .animatedGradient:
                AnimatedGradientBackground(colors: colors)
            case .artworkBlur:
                if let artwork = model.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 70)
                        .saturation(1.3)
                        .overlay(Color.black.opacity(0.35))
                } else {
                    AnimatedGradientBackground(colors: colors)
                }
            case .solid:
                (colors.first ?? Brand.violet).opacity(0.55)
                Color.black.opacity(0.45)
            case .black:
                Color.black
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: model.palette)
    }
}

struct AnimatedGradientBackground: View {
    let colors: [Color]

    var body: some View {
        ZStack {
            (colors.first ?? Brand.violet).opacity(0.6)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                Canvas { canvas, size in
                    canvas.addFilter(.blur(radius: min(size.width, size.height) * 0.22))
                    let palette = colors.isEmpty ? [Brand.violet, Brand.pink] : colors
                    for (index, color) in palette.enumerated() {
                        let phase = Double(index) * 1.7
                        let x = size.width * (0.5 + 0.38 * sin(time / 9 + phase))
                        let y = size.height * (0.5 + 0.38 * cos(time / 11 + phase * 1.3))
                        let radius = min(size.width, size.height) * (0.55 + 0.08 * sin(time / 7 + phase))
                        canvas.fill(
                            Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                            with: .color(color.opacity(0.9))
                        )
                    }
                }
            }
            Color.black.opacity(0.32)
        }
    }
}

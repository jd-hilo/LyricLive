import LyricCore
import SwiftUI

extension Color {
    init(_ color: RGBColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: 1)
    }

    init(hex: String) {
        self.init(RGBColor(hex: hex) ?? RGBColor(red: 0.36, green: 0.24, blue: 0.96))
    }
}

enum Brand {
    static let violet = Color(hex: "#5B3DF5")
    static let pink = Color(hex: "#FF4F8B")
    static let teal = Color(hex: "#12B5CB")
    static let ink = Color(hex: "#12132B")
}

/// Palette used for gradients in widgets, the Live Activity and the app.
func gradientColors(fromHex hex: [String]) -> [Color] {
    let parsed = hex.compactMap(RGBColor.init(hex:))
    let colors = parsed.isEmpty ? PaletteExtractor.fallback : parsed
    return colors.map { Color($0) }
}

/// Square artwork with a graceful placeholder.
struct ArtworkThumb: View {
    var image: UIImage?
    var cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [Brand.violet, Brand.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Vinyl record with the artwork as its label, used by the widgets.
struct VinylView: View {
    var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(
                    AngularGradient(
                        colors: [Color(white: 0.06), Color(white: 0.16), Color(white: 0.06), Color(white: 0.14), Color(white: 0.06)],
                        center: .center
                    )
                )
                ForEach(0..<5, id: \.self) { ring in
                    Circle()
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.8)
                        .padding(size * (0.06 + 0.055 * CGFloat(ring)))
                }
                ArtworkThumb(image: image, cornerRadius: size)
                    .frame(width: size * 0.42, height: size * 0.42)
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: size * 0.06, height: size * 0.06)
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

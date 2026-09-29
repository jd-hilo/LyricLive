import Foundation

public struct RGBColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    public init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        self.init(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }

    public var hex: String {
        func byte(_ v: Double) -> Int { Int((v * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    /// Hue 0...1, saturation 0...1, brightness 0...1.
    public var hsb: (hue: Double, saturation: Double, brightness: Double) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue
        var hue = 0.0
        if delta > 0 {
            if maxValue == red {
                hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxValue == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, maxValue == 0 ? 0 : delta / maxValue, maxValue)
    }

    public static func fromHSB(hue: Double, saturation: Double, brightness: Double) -> RGBColor {
        let h = (hue - hue.rounded(.down)) * 6
        let s = min(max(saturation, 0), 1)
        let v = min(max(brightness, 0), 1)
        let c = v * s
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let (r, g, b): (Double, Double, Double)
        switch Int(h) {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return RGBColor(red: r + m, green: g + m, blue: b + m)
    }

    public func adjusted(saturation: Double = 1, brightness: Double = 1) -> RGBColor {
        let value = hsb
        return .fromHSB(hue: value.hue, saturation: value.saturation * saturation, brightness: value.brightness * brightness)
    }

    func distance(to other: RGBColor) -> Double {
        let dr = red - other.red, dg = green - other.green, db = blue - other.blue
        return (dr * dr + dg * dg + db * db).squareRoot()
    }
}

/// Picks a handful of vivid, well-separated colours from an image so the lyric background can be
/// tinted like the artwork. Works on raw RGBA8 bytes so it is testable without UIKit.
public enum PaletteExtractor {
    public static let fallback: [RGBColor] = [
        RGBColor(hex: "#5B3DF5")!, RGBColor(hex: "#FF4F8B")!, RGBColor(hex: "#12B5CB")!, RGBColor(hex: "#1B1F3B")!,
    ]

    public static func extract(rgba: [UInt8], width: Int, height: Int, count: Int = 4) -> [RGBColor] {
        guard width > 0, height > 0, rgba.count >= width * height * 4, count > 0 else { return fallback }

        struct Bucket { var n = 0.0; var r = 0.0; var g = 0.0; var b = 0.0 }
        var buckets = [Int: Bucket]()
        let totalPixels = width * height
        let stride = max(1, totalPixels / 6000)

        var pixel = 0
        while pixel < totalPixels {
            let offset = pixel * 4
            let alpha = Double(rgba[offset + 3]) / 255
            if alpha > 0.5 {
                let r = Int(rgba[offset]), g = Int(rgba[offset + 1]), b = Int(rgba[offset + 2])
                let key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)
                var bucket = buckets[key] ?? Bucket()
                bucket.n += 1
                bucket.r += Double(r)
                bucket.g += Double(g)
                bucket.b += Double(b)
                buckets[key] = bucket
            }
            pixel += stride
        }

        let scored: [(color: RGBColor, score: Double)] = buckets.values.map { bucket in
            let color = RGBColor(red: bucket.r / bucket.n / 255, green: bucket.g / bucket.n / 255, blue: bucket.b / bucket.n / 255)
            let hsb = color.hsb
            var score = bucket.n * (0.25 + hsb.saturation)
            if hsb.brightness < 0.15 { score *= 0.1 }
            if hsb.brightness > 0.96 && hsb.saturation < 0.1 { score *= 0.2 }
            return (color, score)
        }.sorted { $0.score > $1.score }

        var picked: [RGBColor] = []
        for candidate in scored where picked.count < count {
            if picked.allSatisfy({ $0.distance(to: candidate.color) > 0.22 }) {
                picked.append(candidate.color)
            }
        }

        if picked.isEmpty { return fallback }
        var index = 0
        while picked.count < count {
            let base = picked[index % picked.count]
            let hue = base.hsb.hue + 0.08 * Double(picked.count)
            picked.append(RGBColor.fromHSB(hue: hue, saturation: max(0.4, base.hsb.saturation), brightness: max(0.35, base.hsb.brightness * 0.8)))
            index += 1
        }
        return picked
    }
}

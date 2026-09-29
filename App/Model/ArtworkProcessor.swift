import CoreGraphics
import LyricCore
import UIKit

enum ArtworkProcessor {
    /// Dominant, well separated colours of an image, used to tint backgrounds.
    static func palette(from image: UIImage, count: Int = 4) -> [RGBColor] {
        guard let cgImage = image.cgImage else { return PaletteExtractor.fallback }
        let side = 32
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return PaletteExtractor.fallback }
        return PaletteExtractor.extract(rgba: bytes, width: side, height: side, count: count)
    }

    /// Downscaled JPEG that widgets and the Live Activity read from the App Group container.
    static func sharedJPEG(from image: UIImage, maxDimension: CGFloat = 360) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}

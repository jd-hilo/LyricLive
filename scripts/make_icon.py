#!/usr/bin/env python3
"""Generates the LyricLive app icon (1024x1024, opaque) with Pillow."""
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 2048  # supersample, then downscale


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, c1, c2, c3):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = lerp(c1, c2, t / 0.55) if t < 0.55 else lerp(c2, c3, (t - 0.55) / 0.45)
    return img


def main(out):
    bg = gradient(S, (45, 27, 140), (91, 61, 245), (255, 79, 139))

    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((S * 0.05, -S * 0.25, S * 0.95, S * 0.55), fill=(255, 255, 255, 60))
    bg = Image.alpha_composite(bg.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(S * 0.06)))

    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # Speech bubble with a tail at the lower left.
    bx0, by0, bx1, by1 = S * 0.18, S * 0.20, S * 0.82, S * 0.70
    d.rounded_rectangle((bx0, by0, bx1, by1), radius=S * 0.14, fill=(255, 255, 255, 255))
    d.polygon([(S * 0.30, by1 - 8), (S * 0.30, S * 0.83), (S * 0.47, by1 - 8)], fill=(255, 255, 255, 255))

    # Lyric lines: dim, bright (current), dim.
    cx = (bx0 + bx1) / 2
    lines = [
        (S * 0.37, S * 0.50, (196, 188, 232, 255)),
        (S * 0.45, S * 0.66, (255, 79, 139, 255)),
        (S * 0.28, S * 0.54, (196, 188, 232, 255)),
    ]
    h = S * 0.062
    y = S * 0.285
    for width, _, color in lines:
        d.rounded_rectangle((cx - width / 2 - S * 0.02, y, cx + width / 2 + S * 0.02, y + h), radius=h / 2, fill=color)
        y += h + S * 0.052

    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow.paste((20, 10, 60, 110), mask=layer.split()[3].filter(ImageFilter.GaussianBlur(S * 0.02)))
    shadow = shadow.transform(shadow.size, Image.AFFINE, (1, 0, 0, 0, 1, -S * 0.018))

    out_img = Image.alpha_composite(Image.alpha_composite(bg, shadow), layer).convert("RGB")
    out_img.resize((1024, 1024), Image.LANCZOS).save(out, "PNG")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")

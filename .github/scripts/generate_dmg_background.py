#!/usr/bin/env python3
"""Generate `.github/dmg_background.png` for the release DMG installer window.

Requires Pillow. Uses the app icon so the installer matches Sip branding.

  python3 .github/scripts/generate_dmg_background.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / ".github" / "dmg_background.png"
ICON = ROOT / "Sip" / "Assets.xcassets" / "AppIcon.appiconset" / "mac_512_2x.png"

# Must match window size in `.github/workflows/release.yml` (width × height of bounds).
W, H = 660, 400


def load_font(size: int, *, prefer_cjk: bool = False) -> ImageFont.ImageFont:
    """Load a UI font. When `prefer_cjk`, try Chinese-capable faces first."""
    cjk_first = [
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Supplemental/Songti.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/Library/Fonts/Arial Unicode.ttf",
    ]
    latin_first = [
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    candidates = (cjk_first + latin_first) if prefer_cjk else (latin_first + cjk_first)
    probe = "安装" if prefer_cjk else "Sip"
    for path in candidates:
        try:
            font = ImageFont.truetype(path, size, index=0)
            # Reject fonts that cannot draw CJK (they often measure .notdef boxes).
            if prefer_cjk:
                bbox = font.getbbox(probe)
                if bbox is None or (bbox[2] - bbox[0]) < size * 0.8:
                    continue
            return font
        except OSError:
            continue
    return ImageFont.load_default()


def make_gradient() -> Image.Image:
    """Cool top → teal bottom, aligned with App Icon palette."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        r = int(168 * (1 - t) + 20 * t)
        g = int(220 * (1 - t) + 190 * t)
        b = int(235 * (1 - t) + 180 * t)
        for x in range(W):
            hx = abs(x - W / 2) / (W / 2)
            dark = 1 - 0.06 * hx
            px[x, y] = (
                max(0, min(255, int(r * dark))),
                max(0, min(255, int(g * dark))),
                max(0, min(255, int(b * dark))),
                255,
            )
    return img


def main() -> None:
    img = make_gradient()

    # Soft center glow
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    cx, cy = W // 2, H // 2 + 20
    for i, alpha in enumerate(range(28, 0, -2)):
        rad = 220 - i * 8
        gdraw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(255, 255, 255, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(24))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # App icon (decorative, top center)
    icon = Image.open(ICON).convert("RGBA")
    icon_size = 56
    icon = icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    shadow = Image.new("RGBA", (icon_size + 16, icon_size + 16), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        [4, icon_size - 6, icon_size + 12, icon_size + 12], fill=(0, 0, 0, 50)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(4))
    ix = (W - icon_size) // 2
    iy = 28
    img.paste(shadow, (ix - 8, iy + 6), shadow)
    img.paste(icon, (ix, iy), icon)
    draw = ImageDraw.Draw(img)

    title_font = load_font(42, prefer_cjk=False)
    hint_font = load_font(16, prefer_cjk=True)
    small_font = load_font(13, prefer_cjk=False)

    title = "Sip"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    title_y = iy + icon_size + 10
    draw.text(((W - tw) / 2, title_y), title, font=title_font, fill=(255, 255, 255, 245))

    hint = "将 Sip 拖入 Applications 文件夹"
    bbox = draw.textbbox((0, 0), hint, font=hint_font)
    hw = bbox[2] - bbox[0]
    hint_y = title_y + th + 10
    draw.text(((W - hw) / 2, hint_y), hint, font=hint_font, fill=(255, 255, 255, 210))

    sub = "Drag Sip to Applications to install"
    bbox = draw.textbbox((0, 0), sub, font=small_font)
    sw = bbox[2] - bbox[0]
    draw.text(((W - sw) / 2, hint_y + 24), sub, font=small_font, fill=(255, 255, 255, 160))

    # Arrow between Sip.app (left ~180) and Applications (right ~480) icon centers.
    # Y matches icon placement in release.yml so the drag path sits between the two icons.
    arrow_y = 200
    arrow_x1, arrow_x2 = 250, 410
    draw.line([(arrow_x1, arrow_y), (arrow_x2 - 8, arrow_y)], fill=(255, 255, 255, 220), width=3)
    draw.polygon(
        [
            (arrow_x2, arrow_y),
            (arrow_x2 - 16, arrow_y - 10),
            (arrow_x2 - 16, arrow_y + 10),
        ],
        fill=(255, 255, 255, 220),
    )
    for x in range(arrow_x1, arrow_x2 - 20, 14):
        draw.ellipse([x, arrow_y + 14, x + 4, arrow_y + 18], fill=(255, 255, 255, 90))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(OUT, "PNG", optimize=True)
    print(f"Wrote {OUT} ({W}x{H}, {OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()

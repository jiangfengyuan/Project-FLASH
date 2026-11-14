# Copyright (c) 2026 Fengyuan Jiang
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Synthetic QA preview sheets for the app icon (approximations, not device screenshots).

System masks and appearance treatments are approximated: iOS / macOS / HarmonyOS masks as a
superellipse, Android masks per launcher shape, iOS dark / tinted / clear as simple composites.
Use them to catch clipping, padding, contrast and halo problems; confirm on real devices.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import generate_app_icons as gen

SIZES = (16, 32, 48, 64, 128, 256, 512, 1024)
LIGHT_BG = (242, 242, 247)
DARK_BG = (28, 28, 30)
COLOR_BG = (63, 125, 200)


def _font(size: int):
    for name in ("DejaVuSans.ttf", "NotoSansCJK-Regular.ttc", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _label(img: Image.Image, text: str, xy, size=14, fill=(40, 40, 40)):
    ImageDraw.Draw(img).text(xy, text, font=_font(size), fill=fill)


def _mask_shape(shape: str, size: int) -> Image.Image:
    ss = 4
    big = size * ss
    m = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(m)
    if shape == "circle":
        d.ellipse([0, 0, big - 1, big - 1], fill=255)
    elif shape == "rounded":
        d.rounded_rectangle([0, 0, big - 1, big - 1], radius=big * 0.18, fill=255)
    elif shape == "teardrop":
        d.rounded_rectangle([0, 0, big - 1, big - 1], radius=big * 0.5, fill=255)
        d.rectangle([big // 2, big // 2, big - 1, big - 1], fill=255)
    elif shape == "square":
        d.rectangle([0, 0, big - 1, big - 1], fill=255)
    else:  # squircle
        return gen.superellipse_mask(size, size)
    return m.resize((size, size), Image.LANCZOS)


def _apply_mask(img: Image.Image, mask: Image.Image) -> Image.Image:
    out = img.convert("RGBA").copy()
    out.putalpha(Image.fromarray(np.minimum(np.asarray(out)[..., 3], np.asarray(mask))))
    return out


def android_adaptive(fg: Image.Image, shape: str, size: int, background=gen.CREAM) -> Image.Image:
    """Compose the 108 dp layers and crop the central 72 dp viewport, then mask."""
    layer = Image.new("RGBA", fg.size, background + (255,))
    layer.alpha_composite(fg.convert("RGBA"))
    inset = round(fg.size[0] * 18 / 108)
    viewport = layer.crop((inset, inset, fg.size[0] - inset, fg.size[1] - inset))
    viewport = gen.resize(viewport, size)
    return _apply_mask(viewport, _mask_shape(shape, size))


def android_themed(mono: Image.Image, shape: str, size: int, dark: bool) -> Image.Image:
    bg, fgc = ((38, 35, 48), (214, 196, 255)) if dark else ((232, 222, 248), (64, 44, 120))
    glyph = Image.new("RGBA", mono.size, fgc + (0,))
    glyph.putalpha(mono.getchannel("A"))
    return android_adaptive(glyph, shape, size, background=bg)


def ios_appearance(outputs, kind: str, size: int) -> Image.Image:
    default = outputs[gen.IOS_DIR / "AppIcon-1024.png"].convert("RGBA")
    dark = outputs[gen.IOS_DIR / "AppIcon-1024-dark.png"]
    tinted = outputs[gen.IOS_DIR / "AppIcon-1024-tinted.png"]
    if kind == "default":
        img = default
    elif kind == "dark":
        img = Image.new("RGBA", (1024, 1024), (36, 36, 40, 255))
        img.alpha_composite(dark)
    elif kind.startswith("tinted"):
        tint = np.array((255, 170, 90) if kind == "tinted-light" else (120, 170, 255), float)
        lum = np.asarray(tinted.getchannel("L")).astype(float) / 255
        a = np.asarray(tinted.getchannel("A")).astype(float) / 255
        base = np.array((22, 22, 26), float) if kind == "tinted-dark" else tint * 0.25
        rgb = base * (1 - a[..., None]) + (tint * lum[..., None]) * a[..., None]
        img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert("RGBA")
    else:  # clear-light / clear-dark: frosted glass over a wallpaper, desaturated foreground
        wall = Image.new("RGBA", (1024, 1024), (70, 110, 160, 255) if kind == "clear-light" else (25, 30, 45, 255))
        glass = Image.new("RGBA", (1024, 1024), (255, 255, 255, 70) if kind == "clear-light" else (0, 0, 0, 90))
        wall.alpha_composite(glass)
        gray = tinted.convert("RGBA")
        fade = np.asarray(gray).copy()
        fade[..., 3] = (fade[..., 3].astype(float) * 0.85).astype(np.uint8)
        wall.alpha_composite(Image.fromarray(fade))
        img = wall
    return _apply_mask(gen.resize(img, size), gen.superellipse_mask(size, size))


def harmony_icon(outputs, size: int) -> Image.Image:
    bg = outputs[gen.HARMONY_ENTRY_MEDIA / "flash_icon_background.png"].convert("RGBA")
    bg.alpha_composite(outputs[gen.HARMONY_ENTRY_MEDIA / "flash_icon_foreground.png"])
    return _apply_mask(gen.resize(bg, size), gen.superellipse_mask(size, size))


def _row(title: str, renders: list[Image.Image], bg) -> Image.Image:
    pad = 16
    width = sum(r.size[0] for r in renders) + pad * (len(renders) + 1) + 220
    height = max(r.size[1] for r in renders) + 2 * pad
    row = Image.new("RGB", (width, height), bg)
    _label(row, title, (pad, pad), 15, (230, 230, 230) if sum(bg) < 300 else (40, 40, 40))
    x = 220
    for r in renders:
        y = (height - r.size[1]) // 2
        row.paste(r, (x, y), r if r.mode == "RGBA" else None)
        x += r.size[0] + pad
    return row


def _stack(rows: list[Image.Image], title: str) -> Image.Image:
    width = max(r.size[0] for r in rows)
    sheet = Image.new("RGB", (width, sum(r.size[1] for r in rows) + 50), (255, 255, 255))
    _label(sheet, title, (16, 14), 18)
    y = 50
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.size[1]
    return sheet


def write_previews(outputs, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    small = (16, 32, 48, 64, 128, 256)

    # 1. Size ladder per platform on light / dark / coloured backgrounds.
    rows = []
    mac = outputs[gen.MAC_DIR / "icon-1024.png"]
    fg = outputs[gen.ANDROID_NODPI / "flash_launcher_foreground.png"]
    for bg_name, bg in (("light", LIGHT_BG), ("dark", DARK_BG), ("colour", COLOR_BG)):
        rows.append(_row(f"iOS default / {bg_name}", [ios_appearance(outputs, "default", s) for s in small], bg))
        rows.append(_row(f"macOS / {bg_name}", [gen.resize(mac, s) for s in small], bg))
        rows.append(_row(f"Android squircle / {bg_name}", [android_adaptive(fg, "squircle", s) for s in small], bg))
        rows.append(_row(f"HarmonyOS / {bg_name}", [harmony_icon(outputs, s) for s in small], bg))
    _stack(rows, "Size ladder 16-256 px (synthetic masks)").save(directory / "01-size-ladder.png")

    # 2. Large sizes (512 / 1024) for halo and resampling inspection.
    big = [ios_appearance(outputs, "default", 512), gen.resize(mac, 512),
           android_adaptive(fg, "circle", 512), harmony_icon(outputs, 512)]
    _stack([_row("iOS / macOS / Android circle / HarmonyOS @512", big, LIGHT_BG),
            _row("same on dark", big, DARK_BG)], "512 px detail").save(directory / "02-large.png")

    # 3. iOS appearances (synthetic approximations of the system treatments).
    kinds = ["default", "dark", "clear-light", "clear-dark", "tinted-light", "tinted-dark"]
    rows = [_row(k, [ios_appearance(outputs, k, s) for s in (60, 120, 240)],
                 DARK_BG if "dark" in k else LIGHT_BG) for k in kinds]
    _stack(rows, "iOS appearances - default/dark/tinted use bundled assets; clear is system-generated (approximation)") \
        .save(directory / "03-ios-appearances.png")

    # 4. Android launcher masks + themed (monochrome) icon.
    mono = outputs[gen.ANDROID_NODPI / "flash_launcher_monochrome.png"]
    shapes = ["circle", "squircle", "rounded", "teardrop", "square"]
    rows = [_row("full colour: " + ", ".join(shapes), [android_adaptive(fg, s, 160) for s in shapes], LIGHT_BG),
            _row("themed light", [android_themed(mono, s, 160, False) for s in shapes], LIGHT_BG),
            _row("themed dark", [android_themed(mono, s, 160, True) for s in shapes], DARK_BG),
            _row("themed 48 px", [android_themed(mono, s, 48, d) for s in ("circle", "squircle") for d in (False, True)],
                 LIGHT_BG)]
    _stack(rows, "Android adaptive masks (72 dp viewport) and themed icons").save(directory / "04-android-masks.png")

    # 5. HarmonyOS layers and launch icon.
    fg_h = outputs[gen.HARMONY_ENTRY_MEDIA / "flash_icon_foreground.png"]
    start = outputs[gen.HARMONY_ENTRY_MEDIA / "flash_standard_icon.png"]
    rows = [_row("foreground / background / masked", [gen.resize(fg_h, 200),
                 gen.resize(outputs[gen.HARMONY_ENTRY_MEDIA / "flash_icon_background.png"].convert("RGBA"), 200),
                 harmony_icon(outputs, 200)], LIGHT_BG),
            _row("startWindowIcon on light / dark", [gen.resize(start, 160)], (247, 249, 250)),
            _row("", [gen.resize(start, 160)], (25, 26, 56))]
    _stack(rows, "HarmonyOS layered icon (mask approximated)").save(directory / "05-harmonyos.png")
    print(f"wrote previews to {directory}")

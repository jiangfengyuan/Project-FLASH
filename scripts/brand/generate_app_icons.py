#!/usr/bin/env python3
# Copyright (c) 2026 Fengyuan Jiang
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Derive every platform app-icon asset from the canonical brand PNG.

Single source of truth: assets/brand/flash-standard-icon.png (1024 px, transparent).
The canonical file is only read, never modified.

    python3 scripts/brand/generate_app_icons.py            # regenerate all derived assets
    python3 scripts/brand/generate_app_icons.py --check    # verify committed assets match
    python3 scripts/brand/generate_app_icons.py --preview DIR   # write QA preview sheets

Requires Python 3.10+, Pillow and NumPy (developer tooling only, not an app dependency).
Rules per platform are documented in docs/brand/APP_ICON.md.
"""

from __future__ import annotations

import argparse
import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
CANONICAL = ROOT / "assets/brand/flash-standard-icon.png"

# Warm cream used behind the artwork wherever a platform needs an opaque background
# (iOS default, macOS plate, Android adaptive background, HarmonyOS background layer).
CREAM = (0xFB, 0xF6, 0xEE)

IOS_DIR = ROOT / "ios/Flash/Assets.xcassets/AppIcon.appiconset"
MAC_DIR = ROOT / "macos/Flash/Assets.xcassets/AppIcon.appiconset"
ANDROID_NODPI = ROOT / "android/app/src/main/res/drawable-nodpi"
HARMONY_ENTRY_MEDIA = ROOT / "harmonyos/entry/src/main/resources/base/media"
HARMONY_APP_MEDIA = ROOT / "harmonyos/AppScope/resources/base/media"

# Android adaptive icon: 108 dp layers; the inner 66 dp circle is never masked.
ANDROID_LAYER_PX = 432          # 108 dp at xxxhdpi (4 px/dp)
ANDROID_SAFE_RADIUS_DP = 32.5   # keep all artwork inside the 33 dp safe radius
# macOS (Big Sur – macOS 15 icon grid): 824 px rounded-rect plate centred on a 1024 canvas.
MAC_PLATE = 824
MAC_SIZES = (16, 32, 64, 128, 256, 512, 1024)
# HarmonyOS layered icon: 1024 px square layers; system applies the mask. Keep the
# foreground away from the corners (Huawei 图标资源规范).
HARMONY_FOREGROUND_SCALE = 0.84
HARMONY_START_ICON = 512


# ---------------------------------------------------------------- image helpers

def load_canonical() -> Image.Image:
    return Image.open(CANONICAL).convert("RGBA")


def resize(img: Image.Image, size: int | tuple[int, int]) -> Image.Image:
    """Lanczos resize in premultiplied alpha (no dark/bright fringes at transparent edges)."""
    if isinstance(size, int):
        size = (size, size)
    if img.size == size:
        return img.copy()
    if img.mode == "RGBA":
        return img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    return img.resize(size, Image.LANCZOS)


def place(art: Image.Image, canvas: int, scale: float) -> Image.Image:
    """Scale the 1024 artwork by `scale` relative to a `canvas` px square and centre it."""
    side = round(canvas * scale)
    layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    scaled = resize(art, side)
    off = (canvas - side) // 2
    layer.alpha_composite(scaled, (off, off))
    return layer


def flatten(art: Image.Image, color=CREAM) -> Image.Image:
    base = Image.new("RGBA", art.size, color + (255,))
    base.alpha_composite(art)
    return base.convert("RGB")


def superellipse_mask(size: int, plate: int, n: float = 5.0, supersample: int = 4) -> Image.Image:
    """Anti-aliased continuous-corner (superellipse) mask of side `plate`, centred in `size`."""
    big = size * supersample
    c = big / 2
    h = plate * supersample / 2
    y, x = np.mgrid[0:big, 0:big] + 0.5
    inside = (np.abs((x - c) / h) ** n + np.abs((y - c) / h) ** n) <= 1.0
    return Image.fromarray((inside * 255).astype(np.uint8)).resize((size, size), Image.LANCZOS)


def max_radius(art: Image.Image) -> float:
    a = np.asarray(art)[..., 3]
    ys, xs = np.nonzero(a > 8)
    c = (art.size[0] - 1) / 2
    return float(np.sqrt((xs - c) ** 2 + (ys - c) ** 2).max())


# ---------------------------------------------------------------- derived assets

def ios_default(art):
    # Opaque (no alpha), artwork 1:1 on cream — App Store icons must not be transparent.
    return flatten(art)


IOS_DARK_EXPOSURE = 0.90


def ios_dark(art):
    # Dark appearance: same 1:1 composition with a transparent background so the system's dark
    # background shows through (Apple: "Provide your dark app icon with a transparent background").
    # The paper covers ~95% of the icon, so it is dimmed slightly (Apple: dark icons are "more
    # subdued"; "avoid excessively bright images") without changing its warm colour.
    rgba = np.asarray(art).astype(np.float64)
    rgba[..., :3] *= IOS_DARK_EXPOSURE
    return Image.fromarray(np.round(rgba).astype(np.uint8), "RGBA")


def ios_tinted(art):
    # Tinted appearance: grayscale (Apple: "Provide your tinted app icon as a grayscale image"),
    # same composition, transparent background. Luminance keeps dark handwriting on light paper.
    rgba = np.asarray(art).astype(np.float64) / 255.0
    lum = 0.2126 * rgba[..., 0] + 0.7152 * rgba[..., 1] + 0.0722 * rgba[..., 2]
    la = np.dstack([np.round(lum * 255), np.round(rgba[..., 3] * 255)]).astype(np.uint8)
    return Image.fromarray(la, "LA")


def mac_master(art):
    # iOS composition (artwork 1:1 on cream), shrunk onto the macOS 824 px plate with a
    # continuous-corner mask and a soft drop shadow in the transparent margin.
    plate = resize(flatten(art).convert("RGBA"), MAC_PLATE)
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    off = (1024 - MAC_PLATE) // 2
    mask = superellipse_mask(1024, MAC_PLATE)
    shadow_alpha = mask.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.28))
    shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    shadow.putalpha(shadow_alpha)
    canvas.alpha_composite(shadow, (0, 10))
    body = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    body.alpha_composite(plate, (off, off))
    body.putalpha(Image.fromarray(np.minimum(np.asarray(body)[..., 3], np.asarray(mask))))
    canvas.alpha_composite(body)
    return canvas


def android_scale(art) -> float:
    """Fraction of the 432 px layer the 1024 artwork occupies so its farthest opaque pixel
    lands on the safe radius (4 px per dp at xxxhdpi)."""
    target_px = ANDROID_SAFE_RADIUS_DP * ANDROID_LAYER_PX / 108.0
    return (target_px / max_radius(art)) * art.size[0] / ANDROID_LAYER_PX


def android_foreground(art):
    return place(art, ANDROID_LAYER_PX, android_scale(art))


def _dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    img = Image.fromarray((mask * 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.MaxFilter(2 * radius + 1))) > 127


# Pencil anchors measured on the canonical 1024 px artwork (source pixels). If the canonical
# file changes, re-measure them (see "Regenerating" in docs/brand/APP_ICON.md) before regenerating.
PENCIL_ERASER = (960.0, 200.0)      # centre of the eraser cap
PENCIL_CONE = (783.0, 543.0)        # axis point where the sharpened cone begins
PENCIL_TIP = (707.0, 643.0)         # graphite point touching the underline
PENCIL_HALF_WIDTH = 40.0
PENCIL_FERRULE = ((933.0, 240.0), (897.0, 347.0))   # ferrule band edges on the axis


def _pencil_silhouette(shape: tuple[int, int], ss: int = 4):
    """Simplified pencil silhouette (body, rounded eraser, cone to the graphite tip) and the
    knocked-out ferrule band edges, as boolean masks of `shape` (h, w)."""
    eraser, cone, tip = (np.array(p) for p in (PENCIL_ERASER, PENCIL_CONE, PENCIL_TIP))
    u = (cone - eraser) / np.linalg.norm(cone - eraser)
    v = np.array([-u[1], u[0]])
    hw = PENCIL_HALF_WIDTH

    def p(q):
        return (q[0] * ss, q[1] * ss)

    size = (shape[1] * ss, shape[0] * ss)
    body = Image.new("L", size, 0)
    d = ImageDraw.Draw(body)
    d.polygon([p(eraser + v * hw), p(cone + v * hw), p(tip), p(cone - v * hw), p(eraser - v * hw)], fill=255)
    cx, cy = p(eraser)
    d.ellipse([cx - hw * ss, cy - hw * ss, cx + hw * ss, cy + hw * ss], fill=255)

    band = Image.new("L", size, 0)
    b = ImageDraw.Draw(band)
    for f in PENCIL_FERRULE:
        f = np.array(f)
        b.line([p(f + v * hw * 1.2), p(f - v * hw * 1.2)], fill=255, width=max(1, int(0.22 * hw * ss)))

    shrink = (shape[1], shape[0])
    return (np.asarray(body.resize(shrink, Image.LANCZOS)) > 127,
            np.asarray(band.resize(shrink, Image.LANCZOS)) > 127)


def monochrome_glyph(art) -> Image.Image:
    """Single-colour (alpha-only) glyph for Android themed icons.

    Knock-out design: the paper silhouette is solid; handwriting, underline, fold shading and
    a thin gap around the pencil are cut out, so the icon stays recognisable in one tint.
    """
    rgba = np.asarray(art).astype(np.float64) / 255.0
    rgb, alpha = rgba[..., :3], rgba[..., 3]
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    hi, lo = rgb.max(2), rgb.min(2)
    sat = np.where(hi > 0, (hi - lo) / np.maximum(hi, 1e-6), 0.0)

    solid = np.clip((alpha - 0.35) / 0.3, 0, 1)

    # Pencil: simplified silhouette measured on the artwork (photographic wood shading would
    # otherwise shred into noise in a single tint).
    pencil, ferrule = _pencil_silhouette(alpha.shape)
    gap = _dilate(pencil, 10) & ~pencil

    # Handwriting / underline: dark, low-saturation strokes on the paper (not the pencil).
    ink = np.clip((0.60 - lum) / 0.08, 0, 1) * (alpha > 0.5) * (sat < 0.45) * ~pencil
    ink = np.asarray(Image.fromarray((ink * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(5))) / 255.0

    # Paper structure: the cream top sheet is far less saturated than the apricot back sheets and
    # the curl's underside, so the boundary of the saturated region traces the curled corner and
    # the stacked sheet edges. Cut it out as a contour about as heavy as the handwriting.
    sat_smooth = np.asarray(Image.fromarray((sat * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))) / 255.0
    warm = (sat_smooth > 0.34) & (alpha > 0.5)
    warm = np.asarray(Image.fromarray((warm * 255).astype(np.uint8)).filter(ImageFilter.ModeFilter(7))) > 127
    contour = _dilate(warm, 4) & ~warm & (alpha > 0.6) & ~_dilate(pencil, 12)
    contour = np.asarray(Image.fromarray((contour * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(5))) > 127

    glyph = np.maximum(solid * (1 - ink) * (1 - gap) * ~contour, pencil * (1 - ferrule))
    glyph_img = Image.fromarray(np.round(glyph * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(3))
    out = Image.new("RGBA", art.size, (255, 255, 255, 0))
    out.putalpha(glyph_img)
    return out


def android_monochrome(art):
    # Same placement as the foreground so the themed icon matches the colour layout.
    return place(monochrome_glyph(art), ANDROID_LAYER_PX, android_scale(art))


def harmony_foreground(art):
    return place(art, 1024, HARMONY_FOREGROUND_SCALE)


def harmony_background(_art):
    return Image.new("RGB", (1024, 1024), CREAM)


def harmony_start_icon(art):
    return resize(art, HARMONY_START_ICON)


# ---------------------------------------------------------------- manifest

IOS_CONTENTS = {
    "images": [
        {"filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        {"appearances": [{"appearance": "luminosity", "value": "dark"}],
         "filename": "AppIcon-1024-dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        {"appearances": [{"appearance": "luminosity", "value": "tinted"}],
         "filename": "AppIcon-1024-tinted.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
    ],
    "info": {"author": "xcode", "version": 1},
}

MAC_CONTENTS = {
    "images": [
        {"filename": f"icon-{px}.png", "idiom": "mac", "scale": scale, "size": f"{pt}x{pt}"}
        for pt in (16, 32, 128, 256, 512)
        for scale, px in (("1x", pt), ("2x", pt * 2))
    ],
    "info": {"author": "xcode", "version": 1},
}

LAYERED = {"layered-image": {"background": "$media:flash_icon_background",
                             "foreground": "$media:flash_icon_foreground"}}


def build(art) -> dict[Path, object]:
    """Map of output path -> PIL image or JSON-serialisable object."""
    mac = mac_master(art)
    out: dict[Path, object] = {
        IOS_DIR / "AppIcon-1024.png": ios_default(art),
        IOS_DIR / "AppIcon-1024-dark.png": ios_dark(art),
        IOS_DIR / "AppIcon-1024-tinted.png": ios_tinted(art),
        IOS_DIR / "Contents.json": IOS_CONTENTS,
        MAC_DIR / "Contents.json": MAC_CONTENTS,
        ANDROID_NODPI / "flash_launcher_foreground.png": android_foreground(art),
        ANDROID_NODPI / "flash_launcher_monochrome.png": android_monochrome(art),
        HARMONY_ENTRY_MEDIA / "flash_standard_icon.png": harmony_start_icon(art),
    }
    for px in MAC_SIZES:
        out[MAC_DIR / f"icon-{px}.png"] = resize(mac, px)
    # Same file names in AppScope and entry (official template layout): AppScope copies
    # override the module's at build time, so both must be identical.
    for media, json_name in ((HARMONY_ENTRY_MEDIA, "layered_image.json"),
                             (HARMONY_APP_MEDIA, "app_layered_image.json")):
        out[media / "flash_icon_foreground.png"] = harmony_foreground(art)
        out[media / "flash_icon_background.png"] = harmony_background(art)
        out[media / json_name] = LAYERED
    return out


def encode(obj) -> bytes:
    if isinstance(obj, Image.Image):
        buf = io.BytesIO()
        obj.save(buf, format="PNG", optimize=True)
        return buf.getvalue()
    return (json.dumps(obj, indent=2, ensure_ascii=False) + "\n").encode()


# ---------------------------------------------------------------- check

def _same_pixels(path: Path, expected: Image.Image) -> str | None:
    actual = Image.open(path)
    if actual.size != expected.size:
        return f"size {actual.size} != {expected.size}"
    if actual.mode != expected.mode:
        return f"mode {actual.mode} != {expected.mode}"
    diff = np.abs(np.asarray(actual).astype(int) - np.asarray(expected).astype(int)).max()
    return None if diff <= 1 else f"pixels differ (max {diff})"


def check(outputs: dict[Path, object]) -> list[str]:
    problems = []
    for path, obj in outputs.items():
        rel = path.relative_to(ROOT)
        if not path.exists():
            problems.append(f"missing: {rel}")
        elif isinstance(obj, Image.Image):
            err = _same_pixels(path, obj)
            if err:
                problems.append(f"stale: {rel}: {err}")
        elif json.loads(path.read_text()) != obj:
            problems.append(f"stale: {rel}: JSON differs")
    # Platform invariants beyond "matches the generator".
    if Image.open(IOS_DIR / "AppIcon-1024.png").mode != "RGB":
        problems.append("iOS default icon must be opaque RGB (no alpha)")
    bg = np.asarray(Image.open(HARMONY_ENTRY_MEDIA / "flash_icon_background.png"))
    if bg.ndim == 3 and bg.shape[2] == 4 and bg[..., 3].min() < 255:
        problems.append("HarmonyOS background layer must not contain transparent pixels")
    fg = Image.open(ANDROID_NODPI / "flash_launcher_foreground.png").convert("RGBA")
    if max_radius(fg) * 108 / ANDROID_LAYER_PX > 33.0:
        problems.append("Android foreground exceeds the 66 dp safe zone")
    adaptive = (ROOT / "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml").read_text()
    if 'monochrome android:drawable="@drawable/flash_launcher_monochrome"' not in adaptive:
        problems.append("ic_launcher.xml monochrome layer must use flash_launcher_monochrome")
    for config, needle in ((ROOT / "harmonyos/AppScope/app.json5", '"$media:app_layered_image"'),
                           (ROOT / "harmonyos/entry/src/main/module.json5", '"$media:layered_image"')):
        if needle not in config.read_text():
            problems.append(f"{config.relative_to(ROOT)} must reference {needle}")
    return problems


# ---------------------------------------------------------------- preview

def preview(outputs: dict[Path, object], directory: Path) -> None:
    """Synthetic QA sheets (not device screenshots)."""
    from preview_sheets import write_previews  # local module next to this script
    write_previews(outputs, directory)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="verify committed assets; do not write")
    parser.add_argument("--preview", type=Path, metavar="DIR", help="write synthetic QA preview sheets")
    args = parser.parse_args()

    art = load_canonical()
    if art.size != (1024, 1024):
        print(f"canonical icon must be 1024x1024, got {art.size}", file=sys.stderr)
        return 1
    outputs = build(art)

    if args.check:
        problems = check(outputs)
        for p in problems:
            print(f"FAIL {p}")
        print("OK: all derived icon assets match the canonical source" if not problems
              else f"{len(problems)} problem(s)")
        return 1 if problems else 0

    if args.preview:
        sys.path.insert(0, str(Path(__file__).parent))
        preview(outputs, args.preview)
        return 0

    for path, obj in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(encode(obj))
        print(f"wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Paper-Writing 设计资产：校验 paper-tokens.json 的对比度，写入抖动向量，生成纸张颗粒 PNG。

只用标准库，结果确定（同一输入产出字节相同的 PNG）。用法：
    python3 tools/design/generate_paper_assets.py          # 校验 + 生成并分发到三端
    python3 tools/design/generate_paper_assets.py --check  # 只校验，不写文件
"""
import json
import math
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOKENS = os.path.join(ROOT, "docs/design/paper-tokens.json")
MASK = (1 << 64) - 1
SIZE = 256  # 128pt @2x


class SeededJitter:
    """与 FlashDesign `SeededJitter` 同算法（FNV-1a 散列 + SplitMix64）。"""

    def __init__(self, seed):
        h = 0xCBF29CE484222325
        for b in seed.encode("utf-8"):
            h ^= b
            h = (h * 0x100000001B3) & MASK
        self.state = h

    def next(self):
        self.state = (self.state + 0x9E3779B97F4A7C15) & MASK
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        z ^= z >> 31
        return (z >> 11) / float(1 << 53) * 2 - 1


def luminance(hex_color):
    v = int(hex_color.lstrip("#"), 16)
    out = []
    for c in ((v >> 16) & 255, (v >> 8) & 255, v & 255):
        c /= 255
        out.append(c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * out[0] + 0.7152 * out[1] + 0.0722 * out[2]


def contrast(a, b):
    x, y = sorted((luminance(a), luminance(b)), reverse=True)
    return (x + 0.05) / (y + 0.05)


def check(tokens):
    failures = []
    colors = tokens["colors"]
    for rule in tokens["contrast"]:
        for bg in rule["bg"]:
            for mode in ("light", "dark"):
                ratio = contrast(colors[rule["fg"]][mode], colors[bg][mode])
                if ratio < rule["min"]:
                    failures.append(f'{rule["fg"]} on {bg} ({mode}) = {ratio:.2f} < {rule["min"]}')
    surfaces = ("pageBackground", "cardSurface")
    for name, tag in tokens["tags"].items():
        for bg in surfaces:
            for mode in ("light", "dark"):
                ratio = contrast(tag["text"][mode], colors[bg][mode])
                if ratio < 4.5:
                    failures.append(f"tag {name} text on {bg} ({mode}) = {ratio:.2f}")
    black = [k for k, v in colors.items() if "#000000" in (v["light"].upper(), v["dark"].upper())]
    failures += [f"{k} uses pure black" for k in black]
    return failures


def grain_png(ink, seed, specks, fibres, alpha_scale):
    """透明底、可无缝平铺的颗粒 + 纤维贴图。"""
    jitter = SeededJitter(seed)
    alpha = [0.0] * (SIZE * SIZE)

    def plot(x, y, a):
        i = (int(y) % SIZE) * SIZE + (int(x) % SIZE)
        alpha[i] = min(1.0, alpha[i] + a)

    def unit():
        return (jitter.next() + 1) / 2

    for _ in range(specks):
        plot(unit() * SIZE, unit() * SIZE, 0.25 + unit() * 0.75)
    for _ in range(fibres):
        x, y = unit() * SIZE, unit() * SIZE
        angle = jitter.next() * math.pi
        length = 8 + unit() * 28
        bend = jitter.next() * 0.02
        for step in range(int(length)):
            plot(x, y, 0.28)
            angle += bend
            x += math.cos(angle)
            y += math.sin(angle)
    r, g, b = (int(ink.lstrip("#")[i : i + 2], 16) for i in (0, 2, 4))
    rows = bytearray()
    for row in range(SIZE):
        rows.append(0)
        for col in range(SIZE):
            rows += bytes((r, g, b, min(255, int(alpha[row * SIZE + col] * alpha_scale * 255))))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + chunk(b"IEND", b"")
    )


GRAIN_TARGETS = {
    "light": [
        "shared/FlashKit/Sources/FlashDesign/Resources/paper_grain_light.png",
        "android/app/src/main/res/drawable-nodpi/paper_grain_light.png",
        "harmonyos/entry/src/main/resources/base/media/paper_grain_light.png",
    ],
    "dark": [
        "shared/FlashKit/Sources/FlashDesign/Resources/paper_grain_dark.png",
        "android/app/src/main/res/drawable-nodpi/paper_grain_dark.png",
        "harmonyos/entry/src/main/resources/base/media/paper_grain_dark.png",
    ],
}


def main():
    with open(TOKENS, encoding="utf-8") as fh:
        tokens = json.load(fh)
    failures = check(tokens)
    if failures:
        print("\n".join(failures))
        sys.exit(1)
    print("contrast ok")
    if "--check" in sys.argv:
        return
    vectors = []
    for seed in ("flash-paper", "greeting", "divider", "闪念", ""):
        jitter = SeededJitter(seed)
        vectors.append({"seed": seed, "values": [round(jitter.next(), 12) for _ in range(6)]})
    tokens["jitterVectors"] = vectors
    with open(TOKENS, "w", encoding="utf-8") as fh:
        json.dump(tokens, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    light = grain_png("#3B2A1E", "flash-paper", 2600, 70, 0.11)
    dark = grain_png("#F4ECDF", "flash-paper-dark", 2200, 60, 0.06)
    for mode, data in (("light", light), ("dark", dark)):
        for rel in GRAIN_TARGETS[mode]:
            path = os.path.join(ROOT, rel)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as fh:
                fh.write(data)
    print("grain", len(light), len(dark))


if __name__ == "__main__":
    main()

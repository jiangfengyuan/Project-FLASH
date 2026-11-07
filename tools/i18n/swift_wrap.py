#!/usr/bin/env python3
"""把 Swift 里不走 LocalizedStringKey 的中文字面量包成 L("…")。

SwiftUI 的 Text("…") / Button("…") 等已按本地化键查找，保持原样；其余（赋给 String 的、
三元、返回值……）包一层 L()，运行时从主 Bundle 的 String Catalog 取译文。
macOS 主 Bundle 没有目录，L() 原样返回中文。  用法：swift_wrap.py [--apply] 路径…
"""
import os
import re
import sys

CJK = re.compile(r"[一-鿿]")
LIT = re.compile(r'"(?:[^"\\\n]|\\.)*"')
# 这些调用的首个字符串参数已是 LocalizedStringKey
AUTO = re.compile(
    r"(?:\bText|\bButton|\bLabel|\bToggle|\bPicker|\bSection|\bMenu|\bTextField|\bSecureField|\bLink|\bDatePicker"
    r"|\bStepper|\bLabeledContent|\bShareLink|\bContentUnavailableView|\bnavigationTitle|\bnavigationSubtitle|\balert"
    r"|\bconfirmationDialog|\baccessibilityLabel|\baccessibilityHint|\baccessibilityValue|\bhelp|\bbadge|\bTab|\bsearchable|\bDisclosureGroup|\bconfigurationDisplayName|\bdescription|\bControlWidgetButton|\bGauge)"
    r"\(\s*(?:verbatim:\s*)?$"
)
SKIP_FILES = ("DebugSeeder.swift", "CanonicalTimeZones.swift", "Previews.swift", "CaptureIntents.swift", "QuickCaptureControlIntent.swift", "FlashDatabase.swift", "Localization.swift")


def wrap_file(path, apply):
    src = open(path, encoding="utf-8").read()
    out, pos, hits = [], 0, []
    in_preview = False
    lines = src.split("\n")
    offset = 0
    new_lines = []
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith("#Preview"):
            in_preview = True
        if in_preview:
            new_lines.append(line)
            if line.startswith("}"):
                in_preview = False
            continue
        code = line
        comment_at = _comment_start(line)
        scan = line if comment_at is None else line[:comment_at]
        if stripped.startswith(("///", "//", "*", "/*")) or "@Suite" in line or "FlashLog." in line or "Perf." in line:
            new_lines.append(line)
            continue
        rebuilt, last = [], 0
        for m in LIT.finditer(scan):
            if not CJK.search(m.group()):
                continue
            before = scan[: m.start()]
            if AUTO.search(before) or re.search(r'\bcase\s*$', before) or re.search(r"L\(\s*$", before) or "verbatim:" in before[-12:]:
                continue
            hits.append(m.group())
            rebuilt.append(scan[last : m.start()] + "L(" + m.group() + ")")
            last = m.end()
        if rebuilt:
            code = "".join(rebuilt) + line[last:]
        new_lines.append(code)
    result = "\n".join(new_lines)
    if hits and apply:
        open(path, "w", encoding="utf-8").write(result)
    return hits


def _comment_start(line):
    in_str = False
    i = 0
    while i < len(line) - 1:
        c = line[i]
        if c == "\\" and in_str:
            i += 2
            continue
        if c == '"':
            in_str = not in_str
        if not in_str and line[i : i + 2] == "//":
            return i
        i += 1
    return None


def main():
    apply = "--apply" in sys.argv
    roots = [a for a in sys.argv[1:] if not a.startswith("--")]
    total = 0
    for root in roots:
        for dp, _, fn in os.walk(root):
            for f in fn:
                if f.endswith(".swift") and f not in SKIP_FILES:
                    p = os.path.join(dp, f)
                    hits = wrap_file(p, apply)
                    total += len(hits)
                    if hits and not apply:
                        print(f"--- {p}")
                        for h in hits:
                            print("   ", h)
    print("wrapped" if apply else "would wrap", total)


if __name__ == "__main__":
    main()

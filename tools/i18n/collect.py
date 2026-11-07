#!/usr/bin/env python3
"""收集三端所有界面文案的键，统一成 {0} 占位，写到 docs/i18n/keys.json。

iOS 从编译产物的 .stringsdata 取（SWIFT_EMIT_LOC_STRINGS=YES），因为只有编译器知道 %lld / %@；
Android、HarmonyOS 扫描源码里的 tr() 与稳定键字面量。用法：collect.py <ios-derived-data>
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CJK = re.compile(r"[一-鿿]")
SPEC = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|\.?\d*lf|\.?\d*f)")
ENGLISH_KEYS = {
    "You recorded", "This week felt...", "Highlights", "A week worth remembering. ✦", "moments", "ideas", "tasks",
    "emotions", "Mostly Positive", "Mostly Low", "Mostly Steady", "Memory", "✦ Flash",
}


def normalize_ios(key):
    index = [0]

    def repl(_):
        out = "{%d}" % index[0]
        index[0] += 1
        return out

    return SPEC.sub(repl, key).replace("%%", "%")


def wanted(key):
    return bool(CJK.search(key)) or key in ENGLISH_KEYS


def ios_keys(derived):
    keys = {}
    for path in glob.glob(os.path.join(derived, "**/*.stringsdata"), recursive=True):
        if "/x86_64/" in path:
            continue
        try:
            data = json.load(open(path, encoding="utf-8"))
        except Exception:
            continue
        source = data.get("source", "")
        if "/macos/" in source or "DebugSeeder" in source or "Preview" in source:
            continue
        for table in data.get("tables", {}).values():
            for entry in table:
                key = entry["key"]
                if wanted(key):
                    keys[normalize_ios(key)] = key
    return keys


LIT_KT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
LIT_ETS = re.compile(r"'((?:[^'\\\n]|\\.)*)'")


def unescape(text):
    return text.replace('\\"', '"').replace("\\'", "'").replace("\\n", "\n").replace("\\\\", "\\")


def scan(root, ext, lit):
    keys = set()
    for dp, _, fn in os.walk(root):
        if "/build" in dp or "/tests" in dp:
            continue
        for f in fn:
            if not f.endswith(ext) or f in ("CanonicalTimeZones.kt", "CanonicalTimeZones.ets"):
                continue
            for line in open(os.path.join(dp, f), encoding="utf-8", errors="ignore"):
                stripped = line.strip()
                if stripped.startswith(("//", "*", "/*")):
                    continue
                code = line.split(" // ")[0]
                for m in lit.finditer(code):
                    text = unescape(m.group(1))
                    if wanted(text):
                        keys.add(text)
    return keys


def resource_keys():
    keys = set()
    for path in (
        "android/app/src/main/res/values/strings.xml",
    ):
        for m in re.finditer(r"<string name=\"[^\"]+\">([^<]*)</string>", open(os.path.join(ROOT, path), encoding="utf-8").read()):
            if CJK.search(m.group(1)):
                keys.add(m.group(1))
    path = os.path.join(ROOT, "harmonyos/entry/src/main/resources/base/element/string.json")
    for entry in json.load(open(path, encoding="utf-8"))["string"]:
        if not entry["name"].startswith("s_") and CJK.search(entry["value"]):
            keys.add(entry["value"])
    return keys


def main():
    derived = sys.argv[1]
    ios = ios_keys(derived)
    android = scan(os.path.join(ROOT, "android/app/src/main/java"), ".kt", LIT_KT)
    harmony = scan(os.path.join(ROOT, "harmonyos/entry/src/main/ets"), ".ets", LIT_ETS)
    resources = resource_keys()
    all_keys = sorted(set(ios) | android | harmony | resources)
    out = {
        "keys": all_keys,
        "ios": {k: ios[k] for k in sorted(ios)},
        "android": sorted(android),
        "harmony": sorted(harmony),
        "resources": sorted(resources),
    }
    os.makedirs(os.path.join(ROOT, "docs/i18n"), exist_ok=True)
    with open(os.path.join(ROOT, "docs/i18n/keys.json"), "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)
    print(len(all_keys), "keys; ios", len(ios), "android", len(android), "harmony", len(harmony))


if __name__ == "__main__":
    main()

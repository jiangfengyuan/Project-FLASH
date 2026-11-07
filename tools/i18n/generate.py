#!/usr/bin/env python3
"""把 docs/i18n/parts/*.tsv 合成 translations.json，并生成三端的语言资源。

- iOS：ios/Flash、ios/FlashWidget、ios/FlashShare 下的 Localizable.xcstrings
- Android：res/values*/strings_generated.xml + i18n/I18nKeys.kt
- HarmonyOS：resources/<locale>/element/string.json（资源名 = 原文 FNV-1a）

默认语言是英语（不支持的系统语言回退英语），简体中文单独成表。
可用 --check 只校验：键齐全、占位符一致、非空。
"""
import glob
import json
import os
import re
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LANGS = ["en", "fr", "ko", "de", "ru", "ar", "ja"]
PLACEHOLDER = re.compile(r"\{(\d+)\}")


def fnv(text):
    h = 0x811C9DC5
    data = text.encode("utf-16-le")
    for i in range(0, len(data), 2):
        h ^= data[i] | (data[i + 1] << 8)
        h = (h * 0x01000193) & 0xFFFFFFFF
    return "s_%08x" % h


def unesc(text):
    return text.replace("\\n", "\n")


def load_table():
    table = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "docs/i18n/parts/*.tsv"))):
        for lineno, line in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
            if not line:
                continue
            cols = line.split("\t")
            if len(cols) != 8:
                sys.exit(f"{path}:{lineno}: {len(cols)} columns")
            key = unesc(cols[0])
            table[key] = {lang: unesc(cols[i + 1]) for i, lang in enumerate(LANGS)}
    return table


def check(table, keys):
    problems = []
    for key in keys:
        if key not in table:
            problems.append(f"missing: {key!r}")
    for key, row in table.items():
        want = sorted(set(PLACEHOLDER.findall(key)))
        for lang, value in row.items():
            if not value.strip() and key.strip():
                problems.append(f"empty {lang}: {key!r}")
            if sorted(set(PLACEHOLDER.findall(value))) != want:
                problems.append(f"placeholder {lang}: {key!r} -> {value!r}")
    return problems


def ios_value(text, spec_of):
    def repl(m):
        i = int(m.group(1))
        return "%%%d$%s" % (i + 1, spec_of[i] if i < len(spec_of) else "@")

    return PLACEHOLDER.sub(repl, text.replace("%", "%%"))


def ios_catalog(table, ios_map, path):
    strings = {}
    for norm, raw in sorted(ios_map.items()):
        row = table.get(norm)
        if row is None:
            continue
        specs = re.findall(r"%(?:\d+\$)?(lld|ld|d|@|\.?\d*lf|\.?\d*f)", raw)
        loc = {}
        for lang in LANGS:
            loc[lang] = {"stringUnit": {"state": "translated", "value": ios_value(row[lang], specs)}}
        loc["zh-Hans"] = {"stringUnit": {"state": "translated", "value": raw if re.search("[\u4e00-\u9fff]", raw) else zh_of(raw)}}
        strings[raw] = {"localizations": loc}
    catalog = {"sourceLanguage": "zh-Hans", "strings": strings, "version": "1.0"}
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(catalog, fh, ensure_ascii=False, indent=2, sort_keys=True)
        fh.write("\n")


# 只有 Memory 的少数文案原本是英文键：简体中文下给中文
ZH_FOR_ENGLISH = {
    "You recorded": "本周记录", "This week felt...": "这周感觉……", "Highlights": "亮点",
    "A week worth remembering. ✦": "值得记住的一周。✦", "moments": "闪念", "ideas": "灵感", "tasks": "任务",
    "emotions": "情绪", "Mostly Positive": "大体积极", "Mostly Low": "大体低落", "Mostly Steady": "大体平稳",
    "Memory": "Memory", "✦ Flash": "✦ Flash",
}


def zh_of(key):
    return ZH_FOR_ENGLISH.get(key, key)


def xml_text(text):
    out = escape(text).replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"').replace("\n", "\\n")
    if out.startswith(("@", "?")):
        out = "\\" + out
    if out != out.strip():
        out = '"' + out.replace('\\"', '"') + '"'
    return out


HAND_ANDROID = {
    "share_target_label": "记到 Flash", "widget_label": "Flash 此刻", "widget_description": "今日记录与待办",
    "tile_label": "Flash 快速记录", "shortcut_idea": "记灵感", "shortcut_log": "记日志",
}
ANDROID_DIRS = {"en": "values", "zh": "values-zh", "fr": "values-fr", "ko": "values-ko", "de": "values-de",
                "ru": "values-ru", "ar": "values-ar", "ja": "values-ja"}


def android(table, keys):
    res = os.path.join(ROOT, "android/app/src/main/res")
    used = [k for k in keys if k in table]
    # 删除旧的手写中文，统一进生成文件；app_name 保留在 strings.xml
    with open(os.path.join(res, "values/strings.xml"), "w", encoding="utf-8") as fh:
        fh.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string name="app_name">Flash Aero</string>\n</resources>\n')
    for lang, folder in ANDROID_DIRS.items():
        os.makedirs(os.path.join(res, folder), exist_ok=True)
        lines = ['<?xml version="1.0" encoding="utf-8"?>', "<!-- 由 tools/i18n/generate.py 生成，勿手改 -->",
                 '<resources xmlns:tools="http://schemas.android.com/tools" tools:ignore="ExtraTranslation,MissingTranslation">']
        for name, source in HAND_ANDROID.items():
            value = source if lang == "zh" else table[source][lang]
            lines.append(f'    <string name="{name}">{xml_text(value)}</string>')
        for key in used:
            value = zh_of(key) if lang == "zh" else table[key][lang]
            lines.append(f'    <string name="{fnv(key)}" formatted="false">{xml_text(value)}</string>')
        lines.append("</resources>")
        with open(os.path.join(res, folder, "strings_generated.xml"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
    # 单个函数的方法体有大小上限，按块分开初始化
    chunks = [used[i : i + 300] for i in range(0, len(used), 300)]
    out = ["// 由 tools/i18n/generate.py 生成，勿手改。", "package com.flash.app.i18n", "", "import com.flash.app.R", "",
           "internal object I18nKeys {", "    val strings: Map<String, Int> = HashMap<String, Int>(%d).apply {" % (len(used) * 2)]
    out += ["        chunk%d(this)" % i for i in range(len(chunks))]
    out += ["    }", "", "    val plurals: Map<String, Int> = emptyMap()", ""]
    for i, chunk in enumerate(chunks):
        out.append("    private fun chunk%d(map: MutableMap<String, Int>) {" % i)
        for key in chunk:
            lit = key.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("$", "\\$")
            out.append(f'        map["{lit}"] = R.string.{fnv(key)}')
        out.append("    }")
        out.append("")
    out[-1] = "}"
    with open(os.path.join(ROOT, "android/app/src/main/java/com/flash/app/i18n/I18nKeys.kt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")


HARMONY_DIRS = {"en": "base", "zh": "zh", "fr": "fr", "ko": "ko", "de": "de", "ru": "ru", "ar": "ar", "ja": "ja"}


def harmony(table, keys):
    res = os.path.join(ROOT, "harmonyos/entry/src/main/resources")
    base_path = os.path.join(res, "base/element/string.json")
    hand_path = os.path.join(ROOT, "docs/i18n/harmony-hand-strings.json")
    if os.path.exists(hand_path):
        hand = json.load(open(hand_path, encoding="utf-8"))
    else:
        hand = [e for e in json.load(open(base_path, encoding="utf-8"))["string"] if not e["name"].startswith("s_")]
        json.dump(hand, open(hand_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    used = [k for k in keys if k in table]
    for lang, folder in HARMONY_DIRS.items():
        entries = []
        for item in hand:
            value = item["value"]
            if re.search("[\u4e00-\u9fff]", value):
                value = value if lang == "zh" else table[value][lang]
            entries.append({"name": item["name"], "value": value})
        for key in used:
            entries.append({"name": fnv(key), "value": zh_of(key) if lang == "zh" else table[key][lang]})
        os.makedirs(os.path.join(res, folder, "element"), exist_ok=True)
        with open(os.path.join(res, folder, "element/string.json"), "w", encoding="utf-8") as fh:
            json.dump({"string": entries}, fh, ensure_ascii=False, indent=1)
            fh.write("\n")


def main():
    keys_doc = json.load(open(os.path.join(ROOT, "docs/i18n/keys.json"), encoding="utf-8"))
    table = load_table()
    problems = check(table, keys_doc["keys"])
    if problems:
        print("\n".join(problems[:60]))
        print(len(problems), "problems")
        sys.exit(1)
    print("ok:", len(table), "translated keys")
    if "--check" in sys.argv:
        return
    with open(os.path.join(ROOT, "docs/i18n/translations.json"), "w", encoding="utf-8") as fh:
        json.dump(table, fh, ensure_ascii=False, indent=1, sort_keys=True)
        fh.write("\n")
    for folder in ("ios/Flash", "ios/FlashWidget", "ios/FlashShare"):
        ios_catalog(table, keys_doc["ios"], os.path.join(ROOT, folder, "Localizable.xcstrings"))
    android(table, sorted(set(keys_doc["android"]) | {k for k in keys_doc["resources"] if k in HAND_ANDROID.values()}))
    harmony(table, sorted(set(keys_doc["harmony"])))


if __name__ == "__main__":
    main()

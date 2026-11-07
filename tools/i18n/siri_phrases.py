#!/usr/bin/env python3
"""生成 ios/Flash/AppShortcuts.xcstrings：Siri / 快捷指令短语的七种语言版本。"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
APP = "${applicationName}"
PHRASES = {
    f"用 {APP} 记一闪": {
        "en": f"Capture a moment in {APP}", "fr": f"Noter un moment dans {APP}", "ko": f"{APP}에 순간 기록",
        "de": f"Moment in {APP} festhalten", "ru": f"Записать момент в {APP}", "ar": f"التقط لحظة في {APP}",
        "ja": f"{APP} でひらめきを記録",
    },
    f"在 {APP} 记录灵感": {
        "en": f"Save an idea in {APP}", "fr": f"Noter une idée dans {APP}", "ko": f"{APP}에 아이디어 기록",
        "de": f"Idee in {APP} notieren", "ru": f"Записать идею в {APP}", "ar": f"احفظ فكرة في {APP}",
        "ja": f"{APP} でアイデアを記録",
    },
    f"Quick capture in {APP}": {
        "en": f"Quick capture in {APP}", "fr": f"Capture rapide dans {APP}", "ko": f"{APP} 빠른 기록",
        "de": f"Schnellerfassung in {APP}", "ru": f"Быстрая запись в {APP}", "ar": f"التقاط سريع في {APP}",
        "ja": f"{APP} でクイック記録",
    },
    f"用 {APP} 记下一个念头": {
        "en": f"Note a thought in {APP}", "fr": f"Noter une pensée dans {APP}", "ko": f"{APP}에 생각 기록",
        "de": f"Gedanken in {APP} festhalten", "ru": f"Записать мысль в {APP}", "ar": f"دوّن فكرة في {APP}",
        "ja": f"{APP} で思いつきを記録",
    },
}


def main():
    strings = {}
    for key, row in PHRASES.items():
        loc = {lang: {"stringSet": {"state": "translated", "values": [value]}} for lang, value in row.items()}
        loc["zh-Hans"] = {"stringSet": {"state": "translated", "values": [key]}}
        strings[key] = {"localizations": loc}
    with open(os.path.join(ROOT, "ios/Flash/AppShortcuts.xcstrings"), "w", encoding="utf-8") as fh:
        json.dump({"sourceLanguage": "zh-Hans", "strings": strings, "version": "1.0"}, fh, ensure_ascii=False, indent=2, sort_keys=True)
        fh.write("\n")


if __name__ == "__main__":
    main()

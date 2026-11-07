#!/usr/bin/env python3
"""把 ArkTS 里的中文字面量包成 tr('…')，模板字符串改成 {0} 占位，并补 import。用法：ets_wrap.py [--apply] 目录"""
import os
import re
import sys

CJK = re.compile(r"[一-鿿]")
ROOT_MARK = "/ets/"
SKIP_FILES = {"I18n.ets", "CanonicalTimeZones.ets", "LocalBackupTransfer.ets"}
SKIP_LINE = re.compile(
    r"^\s*(//|\*|/\*)|^import |\btr\('|hilog\.|console\.|QUICK_STATUSES|WEEKDAY_LABELS|\blabel: '|\bemoji: '|"
    r"^\s*return '[^']*本周|^\s*if \(.*return '本周"
)


def literals(line):
    out, i, n = [], 0, len(line)
    while i < n:
        c = line[i]
        if c == "/" and line[i : i + 2] == "//":
            break
        if c in "'\"`":
            j, depth = i + 1, 0
            while j < n:
                d = line[j]
                if d == "\\":
                    j += 2
                    continue
                if c == "`" and d == "$" and j + 1 < n and line[j + 1] == "{":
                    depth, j = 1, j + 2
                    while j < n and depth:
                        if line[j] == "{":
                            depth += 1
                        elif line[j] == "}":
                            depth -= 1
                        j += 1
                    continue
                if d == c:
                    break
                j += 1
            if j >= n:
                return None  # 跨行模板：跳过整行，留给人工
            out.append((i, j + 1))
            i = j + 1
            continue
        i += 1
    return out


def to_tr(lit):
    quote, body = lit[0], lit[1:-1]
    if quote != "`":
        return "tr(" + lit + ")"
    args, out, i = [], [], 0
    while i < len(body):
        if body[i] == "$" and body[i + 1 : i + 2] == "{":
            j, depth = i + 2, 1
            while depth:
                depth += {"{": 1, "}": -1}.get(body[j], 0)
                j += 1
            args.append(body[i + 2 : j - 1])
            out.append("{%d}" % (len(args) - 1))
            i = j
        else:
            out.append(body[i])
            i += 1
    text = "".join(out).replace("'", "\\'")
    return "tr('%s'%s)" % (text, "".join(", " + a for a in args))


def rel_import(path):
    sub = path.split(ROOT_MARK, 1)[1]
    depth = sub.count("/")
    if sub.startswith("data/"):
        return "./I18n"
    return "../" * depth + "data/I18n"


def process(path, apply):
    lines = open(path, encoding="utf-8").read().split("\n")
    hits = 0
    for idx, line in enumerate(lines):
        if not CJK.search(line) or SKIP_LINE.search(line):
            continue
        spans = literals(line)
        if spans is None:
            print("SKIPPED", path.split(ROOT_MARK)[-1], idx + 1, line.strip()[:90])
            continue
        rebuilt, last = [], 0
        for start, end in spans:
            lit = line[start:end]
            if not CJK.search(lit):
                continue
            rebuilt.append(line[last:start] + to_tr(lit))
            last = end
            hits += 1
        if rebuilt:
            lines[idx] = "".join(rebuilt) + line[last:]
    if hits and apply:
        text = "\n".join(lines)
        if "data/I18n'" not in text and "./I18n'" not in text and "{ tr" not in text:
            insert = 0
            for i, line in enumerate(lines):
                if line.startswith("import "):
                    insert = i
                    break
            lines.insert(insert, "import { tr } from '%s';" % rel_import(path))
            text = "\n".join(lines)
        open(path, "w", encoding="utf-8").write(text)
    return hits


def main():
    apply = "--apply" in sys.argv
    total = 0
    for root in [a for a in sys.argv[1:] if not a.startswith("--")]:
        for dp, _, fn in os.walk(root):
            for f in fn:
                if f.endswith(".ets") and f not in SKIP_FILES:
                    total += process(os.path.join(dp, f), apply)
    print("wrapped" if apply else "would wrap", total)


if __name__ == "__main__":
    main()

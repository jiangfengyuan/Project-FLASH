#!/usr/bin/env python3
"""把 Kotlin 里的中文字面量包成 tr("…")，字符串模板改成 {0} 占位。用法：kotlin_wrap.py [--apply] 目录"""
import os
import re
import sys

CJK = re.compile(r"[一-鿿]")
SKIP_FILES = {"Strings.kt", "I18nKeys.kt", "CanonicalTimeZones.kt", "Models.kt"}
# 这些行的字面量是传给 tr(source) 的稳定键，或不是界面文案
SKIP_LINE = re.compile(
    r"^\s*(//|\*|/\*)|const val |\btr\(\"|@|FlashLog|Log\.[dewi]\(|TabDest\(|listOf\(\"一\"|"
    r"^\s*[A-Z_0-9]+\(\"|^\s*(in \d|else) .*-> \"|greetingSource"
)


def split_literals(line):
    """逐个找出代码里的字符串字面量（处理模板和转义），返回 (start, end) 列表"""
    out, i, n = [], 0, len(line)
    while i < n:
        c = line[i]
        if c == "/" and line[i : i + 2] == "//":
            break
        if c == "'" and i + 2 < n:
            j = line.find("'", i + 1)
            if j != -1 and j - i <= 3:
                i = j + 1
                continue
        if c == '"':
            j, depth = i + 1, 0
            while j < n:
                d = line[j]
                if d == "\\":
                    j += 2
                    continue
                if d == "$" and j + 1 < n and line[j + 1] == "{":
                    depth, j = 1, j + 2
                    while j < n and depth:
                        if line[j] == "{":
                            depth += 1
                        elif line[j] == "}":
                            depth -= 1
                        j += 1
                    continue
                if d == '"':
                    break
                j += 1
            out.append((i, j + 1))
            i = j + 1
            continue
        i += 1
    return out


def to_tr(literal):
    body = literal[1:-1]
    args, out, i = [], [], 0
    while i < len(body):
        c = body[i]
        if c == "\\":
            out.append(body[i : i + 2])
            i += 2
            continue
        if c == "$" and i + 1 < len(body):
            if body[i + 1] == "{":
                j, depth = i + 2, 1
                while depth:
                    if body[j] == "{":
                        depth += 1
                    elif body[j] == "}":
                        depth -= 1
                    j += 1
                args.append(body[i + 2 : j - 1])
                out.append("{%d}" % (len(args) - 1))
                i = j
                continue
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", body[i + 1 :])
            if m:
                args.append(m.group())
                out.append("{%d}" % (len(args) - 1))
                i += 1 + m.end()
                continue
        out.append(c)
        i += 1
    joined = "".join(out)
    suffix = "".join(", " + a for a in args)
    return 'com.flash.app.i18n.tr("%s"%s)' % (joined, suffix)


def process(path, apply):
    lines = open(path, encoding="utf-8").read().split("\n")
    hits = 0
    for idx, line in enumerate(lines):
        if not CJK.search(line) or SKIP_LINE.search(line):
            continue
        spans = split_literals(line)
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
            if not apply:
                print(path.split("/com/flash/app/")[-1], lines[idx].strip()[:150])
    if hits and apply:
        open(path, "w", encoding="utf-8").write("\n".join(lines))
    return hits


def main():
    apply = "--apply" in sys.argv
    total = 0
    for root in [a for a in sys.argv[1:] if not a.startswith("--")]:
        for dp, _, fn in os.walk(root):
            for f in fn:
                if f.endswith(".kt") and f not in SKIP_FILES:
                    total += process(os.path.join(dp, f), apply)
    print("wrapped" if apply else "would wrap", total)


if __name__ == "__main__":
    main()

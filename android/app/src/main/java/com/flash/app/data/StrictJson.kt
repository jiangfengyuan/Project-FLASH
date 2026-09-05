package com.flash.app.data

/** org.json also accepts JavaScript-like syntax; the standard importer must accept JSON only. */
internal class StrictJson(private val text: String) {
    private var index = 0
    fun validate() {
        value(0)
        whitespace()
        if (index != text.length) fail()
    }
    private fun fail(): Nothing = throw Backup.BackupFormatException("/：JSON 语法不合法（位置 $index）")
    private fun whitespace() { while (index < text.length && text[index] in " \t\r\n") index++ }
    private fun take(c: Char): Boolean {
        whitespace()
        if (index < text.length && text[index] == c) { index++; return true }
        return false
    }
    private fun expect(c: Char) { if (!take(c)) fail() }
    private fun value(depth: Int) {
        whitespace()
        if (depth > 128 || index == text.length) fail()
        when (text[index]) {
            '{' -> {
                index++
                if (take('}')) return
                val keys = mutableSetOf<String>()
                do {
                    whitespace()
                    val key = string()
                    if (!keys.add(key)) {
                        throw Backup.BackupFormatException("/：JSON 对象包含重复键：$key")
                    }
                    expect(':')
                    value(depth + 1)
                } while (take(','))
                expect('}')
            }
            '[' -> {
                index++
                if (take(']')) return
                do { value(depth + 1) } while (take(','))
                expect(']')
            }
            '"' -> string()
            't' -> literal("true")
            'f' -> literal("false")
            'n' -> literal("null")
            else -> number()
        }
    }
    private fun literal(value: String) {
        if (!text.startsWith(value, index)) fail()
        index += value.length
    }
    private fun string(): String {
        if (index >= text.length || text[index++] != '"') fail()
        val result = StringBuilder()
        while (index < text.length) {
            val c = text[index++]
            if (c == '"') return result.toString()
            if (c < ' ') fail()
            if (c == '\\') {
                if (index == text.length) fail()
                when (text[index++]) {
                    '"' -> result.append('"')
                    '\\' -> result.append('\\')
                    '/' -> result.append('/')
                    'b' -> result.append('\b')
                    'f' -> result.append('\u000C')
                    'n' -> result.append('\n')
                    'r' -> result.append('\r')
                    't' -> result.append('\t')
                    'u' -> {
                        var codeUnit = 0
                        repeat(4) {
                            if (index == text.length) fail()
                            codeUnit = codeUnit * 16 + text[index++].digitToIntOrNull(16).orFail()
                        }
                        result.append(codeUnit.toChar())
                    }
                    else -> fail()
                }
            } else result.append(c)
        }
        fail()
    }

    private fun Int?.orFail(): Int = this ?: fail()
    private fun number() {
        if (index < text.length && text[index] == '-') index++
        if (index == text.length) fail()
        if (text[index] == '0') index++ else digits()
        if (index < text.length && text[index] == '.') { index++; digits() }
        if (index < text.length && text[index] in "eE") {
            index++
            if (index < text.length && text[index] in "+-") index++
            digits()
        }
    }
    private fun digits() {
        val start = index
        while (index < text.length && text[index] in '0'..'9') index++
        if (index == start) fail()
    }
}

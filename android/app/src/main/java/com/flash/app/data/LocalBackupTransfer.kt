// Copyright (c) 2026 Fengyuan Jiang · MPL-2.0
package com.flash.app.data

/** Legacy LAN is temporarily disabled; no networking implementation ships. */
object LocalBackupTransfer {
    const val UNAVAILABLE_MESSAGE = "局域网传输暂时停用：旧协议存在安全风险。请使用‘导出备份’或‘系统分享’，通过可信渠道传输 JSON 文件。"
    data class Device(val id: String, val name: String, val host: String, val port: Int)
}

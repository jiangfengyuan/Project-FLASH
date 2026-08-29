// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import android.content.Context
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * 跨设备备份传输：只把一次性 JSON 副本写入受 FileProvider 保护的缓存目录。
 * 接收端仍走现有导入校验，模块本身不申请网络权限、不上传数据。
 */
object BackupTransfer {
    private const val SHARE_DIRECTORY = "shared-backups"
    private const val FILE_PREFIX = "flash-aero-backup-"
    private const val MAX_CACHE_AGE_MILLIS = 24L * 60 * 60 * 1000
    private val FILE_TIMESTAMP = DateTimeFormatter.ofPattern("yyyy-MM-dd-HHmmss")

    fun createShareUri(context: Context, json: String): Uri {
        val directory = File(context.cacheDir, SHARE_DIRECTORY).apply {
            check(exists() || mkdirs()) { "无法创建备份传输目录" }
        }
        directory.listFiles()
            ?.filter {
                it.isFile &&
                    it.name.startsWith(FILE_PREFIX) &&
                    it.extension == "json" &&
                    System.currentTimeMillis() - it.lastModified() > MAX_CACHE_AGE_MILLIS
            }
            ?.forEach { it.delete() }

        val suffix = UUID.randomUUID().toString().take(8)
        val file = File(
            directory,
            "$FILE_PREFIX${LocalDateTime.now().format(FILE_TIMESTAMP)}-$suffix.json",
        )
        file.writeText(json, Charsets.UTF_8)
        return FileProvider.getUriForFile(
            context,
            "${context.packageName}.backup-files",
            file,
        )
    }
}

// Copyright (c) 2026 Fengyuan Jiang · MPL-2.0
package com.flash.app.data

import android.os.SystemClock
import java.net.Socket
import java.net.SocketTimeoutException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.*

/** Single coroutine owns native calls; cancellation closes blocking socket I/O.
 * No database writes and no snapshot before both authenticated confirmations. */
internal class SecureLanConnection(private val socket: Socket) {
    private val confirmed = AtomicBoolean(false)
    private val cancelled = AtomicBoolean(false)
    private val writeBegan = AtomicLong(0)
    fun confirm() { confirmed.set(true) }
    fun cancel() { cancelled.set(true); runCatching { socket.close() } }
    private fun checked(code: Long): Long {
        check(code >= 0) { "LAN_NATIVE_$code" }
        return code
    }
    suspend fun run(
        sender: Boolean, remaining: Long,
        snapshot: suspend () -> String,
        onState: (Int, List<Int>) -> Unit,
    ): Backup.ImportResult? = withContext(Dispatchers.IO) {
        val id = LanNative.create(if (sender) 1 else 2, SystemClock.elapsedRealtime(), remaining)
        check(id > 0) { "LAN_NATIVE_UNAVAILABLE" }
        val owner = currentCoroutineContext().job
        val deadline = AtomicLong(SystemClock.elapsedRealtime() + remaining)
        var transferStarted = false
        val guard = launch(Dispatchers.IO) {
            while (isActive) {
                delay(100)
                val began = writeBegan.get()
                val now = SystemClock.elapsedRealtime()
                if (cancelled.get() || now >= deadline.get() || (began != 0L && now - began >= 10_000)) {
                    this@SecureLanConnection.cancel()
                    owner.cancel(CancellationException("LAN timeout or cancellation")); break
                }
            }
        }
        var validated: Backup.ImportResult? = null
        val input = ByteArray(65_536)
        try {
            socket.soTimeout = 250
            var previous = 0
            while (!cancelled.get()) {
                currentCoroutineContext().ensureActive()
                val now = SystemClock.elapsedRealtime()
                checked(LanNative.action(id, 3, now, 0))
                if (confirmed.getAndSet(false)) checked(LanNative.action(id, 5, now, 0))
                val state = checked(LanNative.action(id, 1, now, 0)).toInt()
                check(state != 14) { "LAN_NATIVE_FAILED" }
                if (!transferStarted && state in 8..12) {
                    transferStarted = true; deadline.set(now + 120_000)
                }
                if (state != previous) {
                    onState(state, if (state == 6) LanNative.sas(id)?.toList() ?: error("LAN_CODE") else emptyList())
                    previous = state
                }
                when (state) {
                    8 -> {
                        val json = snapshot()
                        currentCoroutineContext().ensureActive()
                        check(!cancelled.get())
                        val bytes = json.toByteArray(Charsets.UTF_8)
                        try { checked(LanNative.input(id, 2, bytes, SystemClock.elapsedRealtime())) }
                        finally { bytes.fill(0) }
                    }
                    11 -> {
                        val bytes = LanNative.received(id) ?: error("LAN_BACKUP")
                        try {
                            // Core already rejects malformed UTF-8 and BOM.
                            val json = bytes.toString(Charsets.UTF_8)
                            val backup = Backup.parseStrict(json)
                            // The quarantined LAN contract only negotiates v2 content.
                            check(backup.sourceVersion == Backup.BACKUP_VERSION) { "LAN_BACKUP" }
                            currentCoroutineContext().ensureActive()
                            check(!cancelled.get())
                            checked(LanNative.action(id, 8, SystemClock.elapsedRealtime(), 1))
                            validated = backup
                        } finally { bytes.fill(0) }
                    }
                }
                // JNI returns null for no queued packet; state/tick checks above
                // and below distinguish errors. Native owns immutable ciphertext.
                val packet = LanNative.output(id, SystemClock.elapsedRealtime())
                checked(LanNative.action(id, 1, SystemClock.elapsedRealtime(), 0))
                if (packet != null) {
                    writeBegan.set(SystemClock.elapsedRealtime())
                    try { socket.getOutputStream().write(packet) }
                    finally { writeBegan.set(0) }
                    checked(LanNative.action(id, 4, SystemClock.elapsedRealtime(), 0))
                    continue
                }
                if (checked(LanNative.action(id, 1, SystemClock.elapsedRealtime(), 0)) == 13L) {
                    return@withContext if (sender) null else validated ?: error("LAN_BACKUP")
                }
                try {
                    val count = socket.getInputStream().read(input)
                    check(count > 0) { "LAN_RECEIPT_MISSING" }
                    val chunk = input.copyOf(count)
                    try { checked(LanNative.input(id, 1, chunk, SystemClock.elapsedRealtime())) }
                    finally { chunk.fill(0); input.fill(0, 0, count) }
                } catch (_: SocketTimeoutException) { /* watchdog ticks on every loop */ }
            }
            throw CancellationException("LAN cancelled")
        } finally {
            guard.cancel(); input.fill(0)
            LanNative.action(id, 9, SystemClock.elapsedRealtime(), 0)
            this@SecureLanConnection.cancel()
        }
    }
}

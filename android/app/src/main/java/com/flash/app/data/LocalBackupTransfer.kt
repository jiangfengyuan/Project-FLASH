// Copyright (c) 2026 Fengyuan Jiang · MPL-2.0
package com.flash.app.data

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.SystemClock
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.UUID
import kotlinx.coroutines.*

object LocalBackupTransfer {
    const val ENABLED = false // four-platform physical acceptance is still pending
    const val SERVICE_TYPE = "_flashbackup2._tcp."
    const val UNAVAILABLE_MESSAGE = "局域网传输暂时停用：安全 LAN v2 正在验收。请使用‘导出备份’或‘系统分享’传输 JSON 文件；旧版 LAN 不再支持。"
    data class Device(val id: String, val name: String, val host: String = "", val port: Int = 0)
    enum class Phase { IDLE, WAITING, DISCOVERING, HANDSHAKE, CONFIRMING, WAITING_FOR_PEER, TRANSFERRING, VERIFYING, COMPLETED, FAILED }
}

/** Main-thread owner. Discovery names are untrusted, ephemeral display labels. */
internal class SecureLanController(
    context: Context, private val scope: CoroutineScope,
    private val onPhase: (LocalBackupTransfer.Phase, List<Int>) -> Unit,
    private val onDevices: (List<LocalBackupTransfer.Device>) -> Unit,
    private val onSent: () -> Unit,
    private val onReceived: (Backup.ImportResult) -> Unit,
    private val onFailure: (String) -> Unit,
    private val enabled: Boolean = LocalBackupTransfer.ENABLED,
) {
    private val nsd = context.applicationContext.getSystemService(Context.NSD_SERVICE) as NsdManager
    private var registration: NsdManager.RegistrationListener? = null
    private var discovery: NsdManager.DiscoveryListener? = null
    private var server: ServerSocket? = null
    private var socket: Socket? = null
    private var active: SecureLanConnection? = null
    private var operation: Job? = null
    private var opening: Job? = null
    private var epoch = 0L
    private var attempt = 0L
    private var end = 0L
    private var failures = 0
    private var retryAfter = 0L
    private var connecting = false
    private var sending = false
    private var provider: (suspend () -> String)? = null
    private val found = linkedMapOf<String, NsdServiceInfo>()
    private fun current(e: Long) = epoch == e
    private fun dispatch(e: Long, block: () -> Unit) { scope.launch(Dispatchers.Main.immediate) { if (current(e)) block() } }
    private fun begin(sender: Boolean): Long? {
        cancel()
        if (!enabled) { onFailure(LocalBackupTransfer.UNAVAILABLE_MESSAGE); return null }
        sending = sender; failures = 0; retryAfter = 0; end = SystemClock.elapsedRealtime() + 120_000
        val e = epoch
        onPhase(if (sender) LocalBackupTransfer.Phase.WAITING else LocalBackupTransfer.Phase.DISCOVERING, emptyList())
        opening = scope.launch {
            while (isActive && current(e)) {
                delay(250)
                if (!connecting && SystemClock.elapsedRealtime() >= end) { fail("本次开启已超时，请重新发起"); return@launch }
            }
        }
        return e
    }
    fun send(snapshot: suspend () -> String) {
        val e = begin(true) ?: return
        provider = snapshot
        operation = scope.launch {
            var acquiredListener: ServerSocket? = null
            try {
                // Capture ownership on IO so prompt cancellation during the
                // dispatcher handoff cannot discard a live descriptor.
                withContext(Dispatchers.IO) { acquiredListener = ServerSocket(0) }
                val listener = checkNotNull(acquiredListener)
                if (!current(e)) return@launch
                listener.soTimeout = 250
                server = listener
                val registration = object : NsdManager.RegistrationListener {
                    override fun onServiceRegistered(info: NsdServiceInfo) = Unit
                    override fun onServiceUnregistered(info: NsdServiceInfo) = Unit
                    override fun onRegistrationFailed(info: NsdServiceInfo, code: Int) = dispatch(e) { fail("无法开启局域网服务，请检查网络权限") }
                    override fun onUnregistrationFailed(info: NsdServiceInfo, code: Int) = Unit
                }
                this@SecureLanController.registration = registration
                nsd.registerService(NsdServiceInfo().apply {
                    serviceName = "Flash-" + UUID.randomUUID().toString().take(8)
                    serviceType = LocalBackupTransfer.SERVICE_TYPE; port = listener.localPort
                }, NsdManager.PROTOCOL_DNS_SD, registration)
                while (current(e) && isActive) {
                    var acquiredPeer: Socket? = null
                    try {
                        withContext(Dispatchers.IO) {
                            try { acquiredPeer = listener.accept() } catch (_: java.net.SocketTimeoutException) { }
                        }
                        val accepted = acquiredPeer ?: continue
                        val now = SystemClock.elapsedRealtime()
                        if (!current(e) || now >= end || now < retryAfter || failures >= 3) continue
                        socket = accepted; connecting = true
                        transfer(accepted, e)
                    } finally {
                        runCatching { acquiredPeer?.close() }
                    }
                }
            } catch (error: Exception) {
                if (current(e) && error !is CancellationException) fail("无法建立安全局域网连接，请检查本地网络权限")
            } finally {
                runCatching { acquiredListener?.close() }
            }
        }
    }
    fun receive() {
        val e = begin(false) ?: return
        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(type: String) = Unit
            override fun onDiscoveryStopped(type: String) = Unit
            override fun onStartDiscoveryFailed(type: String, code: Int) = dispatch(e) { fail("无法发现设备，请检查网络权限") }
            override fun onStopDiscoveryFailed(type: String, code: Int) = Unit
            override fun onServiceFound(info: NsdServiceInfo) = dispatch(e) {
                if (info.serviceType.trimEnd('.') == LocalBackupTransfer.SERVICE_TYPE.trimEnd('.')) {
                    // Bound discovery memory even on a hostile local network.
                    if (found.size < 64 || found.containsKey(info.serviceName)) found[info.serviceName] = info
                    publishDevices()
                }
            }
            override fun onServiceLost(info: NsdServiceInfo) = dispatch(e) { found.remove(info.serviceName); publishDevices() }
        }
        discovery = listener
        try { nsd.discoverServices(LocalBackupTransfer.SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener) }
        catch (_: Exception) { fail("无法发现设备，请检查网络权限") }
    }
    private fun publishDevices() { onDevices(found.keys.map { LocalBackupTransfer.Device(it, it.take(80)) }) }
    @Suppress("DEPRECATION")
    fun connect(device: LocalBackupTransfer.Device) {
        val now = SystemClock.elapsedRealtime()
        val info = found[device.id] ?: return
        if (sending || connecting || now >= end || now < retryAfter || failures >= 3) return
        connecting = true
        attempt += 1
        val a = attempt
        val e = epoch
        onPhase(LocalBackupTransfer.Phase.HANDSHAKE, emptyList())
        // API 26 supports one resolve at a time; resolve only the selected item.
        operation = scope.launch { delay(minOf(10_000, end - now)); if (current(e) && attempt == a && active == null) connectionFailed() }
        try {
            nsd.resolveService(info, object : NsdManager.ResolveListener {
                override fun onResolveFailed(info: NsdServiceInfo, code: Int) = dispatch(e) { if (attempt == a && connecting && active == null) connectionFailed() }
                override fun onServiceResolved(info: NsdServiceInfo) = dispatch(e) {
                    if (attempt != a || !connecting || active != null || SystemClock.elapsedRealtime() >= end) return@dispatch
                    operation?.cancel()
                    operation = scope.launch {
                        val client = Socket(); socket = client
                        try {
                            withContext(Dispatchers.IO) { client.connect(InetSocketAddress(info.host, info.port), minOf(10_000, end - SystemClock.elapsedRealtime()).coerceAtLeast(1).toInt()) }
                            if (!current(e) || attempt != a) { client.close(); return@launch }
                            transfer(client, e)
                        } catch (error: Exception) {
                            client.close()
                            if (current(e) && attempt == a && error !is CancellationException) connectionFailed()
                        }
                    }
                }
            })
        } catch (_: Exception) { connectionFailed() }
    }
    private suspend fun transfer(socket: Socket, e: Long) {
        val channel = SecureLanConnection(socket); active = channel
        onPhase(LocalBackupTransfer.Phase.HANDSHAKE, emptyList())
        try {
            val backup = channel.run(sending, (end - SystemClock.elapsedRealtime()).coerceAtLeast(1),
                snapshot = { provider?.invoke() ?: error("LAN_SNAPSHOT") }) { state, code -> dispatch(e) {
                if (active !== channel) return@dispatch
                onPhase(when (state) {
                    6 -> LocalBackupTransfer.Phase.CONFIRMING
                    7 -> LocalBackupTransfer.Phase.WAITING_FOR_PEER
                    8, 9, 10, 12 -> LocalBackupTransfer.Phase.TRANSFERRING
                    11 -> LocalBackupTransfer.Phase.VERIFYING
                    else -> LocalBackupTransfer.Phase.HANDSHAKE
                }, code)
            } }
            if (!current(e)) return
            val wasSending = sending
            cancel(); onPhase(LocalBackupTransfer.Phase.COMPLETED, emptyList())
            if (wasSending) onSent() else onReceived(backup ?: error("LAN_BACKUP"))
        } catch (error: Exception) {
            // A native watchdog cancellation is a connection failure; user
            // cancellation has already advanced the opening epoch.
            if (current(e)) connectionFailed()
        } finally { channel.cancel(); if (current(e)) { active = null; this.socket = null } }
    }
    private fun connectionFailed() {
        attempt += 1
        active?.cancel(); active = null; runCatching { socket?.close() }; socket = null
        connecting = false; failures += 1
        if (failures >= 3 || SystemClock.elapsedRealtime() >= end) { fail("安全传输未完成，请重新发起；收到备份后仍需确认导入"); return }
        retryAfter = SystemClock.elapsedRealtime() + failures * 1_000
        onPhase(if (sending) LocalBackupTransfer.Phase.WAITING else LocalBackupTransfer.Phase.DISCOVERING, emptyList())
    }
    fun confirm() { active?.confirm() }
    fun reject() { fail("短码不一致，已取消本次传输") }
    private fun fail(message: String) { cancel(); onPhase(LocalBackupTransfer.Phase.FAILED, emptyList()); onFailure(message) }
    fun cancel() {
        epoch += 1
        attempt += 1
        active?.cancel(); active = null
        runCatching { socket?.close() }; socket = null
        runCatching { server?.close() }; server = null
        registration?.let { runCatching { nsd.unregisterService(it) } }; registration = null
        discovery?.let { runCatching { nsd.stopServiceDiscovery(it) } }; discovery = null
        operation?.cancel(); operation = null; opening?.cancel(); opening = null
        provider = null; found.clear(); connecting = false; onDevices(emptyList())
    }
}

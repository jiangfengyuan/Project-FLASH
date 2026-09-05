// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import java.io.InputStream
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketTimeoutException
import java.security.SecureRandom
import java.util.concurrent.atomic.AtomicBoolean

/** 单次、短时的局域网备份通道。Bonjour/NSD 只负责发现，JSON 通过临时 TCP 连接传输。 */
object LocalBackupTransfer {
    const val SERVICE_TYPE = "_flashbackup._tcp."
    const val SESSION_MILLIS = 60 * 1000L
    private const val PROTOCOL = "FLASH-AERO/1"
    private const val MAX_PIN_ATTEMPTS = 5
    private const val SOCKET_TIMEOUT = 15_000

    data class Device(val id: String, val name: String, val host: String, val port: Int)

    fun generatePin(): String = SecureRandom().nextInt(10_000).toString().padStart(4, '0')

    /**
     * 部分 Android 版本回调的 serviceType 不带末尾 "."，去掉尾点归一后再比较，
     * 避免把合法发现结果静默丢弃。
     */
    internal fun isFlashBackupServiceType(serviceType: String?): Boolean =
        serviceType?.trimEnd('.') == SERVICE_TYPE.trimEnd('.')

    class Sender(private val context: Context, private val json: String) {
        val pin: String = generatePin()
        private val stopped = AtomicBoolean(false)
        private val server = ServerSocket(0).apply { soTimeout = 1_000 }
        private val nsd = context.getSystemService(Context.NSD_SERVICE) as NsdManager
        @Volatile private var registered = false

        suspend fun run(): Boolean {
            val service = NsdServiceInfo().apply {
                serviceName = "Flash Aero (${Build.MODEL.take(24)})"
                serviceType = SERVICE_TYPE
                port = server.localPort
            }
            nsd.registerService(service, NsdManager.PROTOCOL_DNS_SD, registrationListener)
            return try {
                serveSession(server, pin, json) { stopped.get() }
            } finally {
                stop()
            }
        }

        fun stop() {
            if (!stopped.compareAndSet(false, true)) return
            runCatching { server.close() }
            if (registered) runCatching { nsd.unregisterService(registrationListener) }
        }

        private val registrationListener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(serviceInfo: NsdServiceInfo) {
                registered = true
                if (stopped.get()) runCatching { nsd.unregisterService(this) }
            }
            override fun onRegistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) { stop() }
            override fun onServiceUnregistered(serviceInfo: NsdServiceInfo) { registered = false }
            override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) = Unit
        }
    }

    /**
     * 在 [server] 上接受连接，直到配对成功、被取消或 [SESSION_MILLIS] 会话超时。
     * 只有请求行格式合法（FLASH-AERO/1 协议头正确）但 PIN 错误的尝试才计入
     * [MAX_PIN_ATTEMPTS]；格式非法的连接（端口扫描、误连等垃圾流量）直接关闭
     * 且不计数，避免耗尽合法接收方的配对机会。独立于此以便脱离 NSD 单测。
     */
    internal suspend fun serveSession(
        server: ServerSocket,
        pin: String,
        json: String,
        isStopped: () -> Boolean,
    ): Boolean {
        val deadline = System.currentTimeMillis() + SESSION_MILLIS
        var attempts = 0
        while (!isStopped() && currentCoroutineContext().isActive &&
            System.currentTimeMillis() < deadline && attempts < MAX_PIN_ATTEMPTS
        ) {
            val socket = try {
                server.accept()
            } catch (_: SocketTimeoutException) {
                continue
            }
            socket.use { client ->
                client.soTimeout = SOCKET_TIMEOUT
                val request = runCatching { readLine(client.getInputStream(), 64) }.getOrNull()
                if (request == "$PROTOCOL $pin") {
                    val payload = json.toByteArray(Charsets.UTF_8)
                    client.getOutputStream().apply {
                        write("OK ${payload.size}\n".toByteArray())
                        write(payload)
                        flush()
                    }
                    return true
                }
                if (request?.startsWith("$PROTOCOL ") == true) {
                    attempts++
                    runCatching {
                        client.getOutputStream().apply {
                            write("ERR PIN\n".toByteArray())
                            flush()
                        }
                    }
                }
                // 格式非法的请求：不回复、不计数，use 结束时直接关闭连接。
            }
        }
        return false
    }

    class Discovery(context: Context, private val onDevicesChanged: (List<Device>) -> Unit) {
        private val nsd = context.getSystemService(Context.NSD_SERVICE) as NsdManager
        private val wifiManager =
            context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        private val devices = linkedMapOf<String, Device>()
        private var active = false
        private var multicastLock: WifiManager.MulticastLock? = null

        fun start() {
            if (active) return
            active = true
            acquireMulticastLock()
            try {
                nsd.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
            } catch (t: Throwable) {
                stop()
                throw t
            }
        }

        fun stop() {
            if (!active) return
            active = false
            runCatching { nsd.stopServiceDiscovery(listener) }
            releaseMulticastLock()
            devices.clear()
            onDevicesChanged(emptyList())
        }

        // 多数设备/ROM 未持锁时会过滤 mDNS 组播，发现期间必须持有 MulticastLock。
        // 关闭引用计数并用 isHeld 防护，避免重复 acquire/release 计数错乱。
        private fun acquireMulticastLock() {
            val lock = multicastLock ?: wifiManager.createMulticastLock("flash-discovery").apply {
                setReferenceCounted(false)
                multicastLock = this
            }
            if (!lock.isHeld) runCatching { lock.acquire() }
        }

        private fun releaseMulticastLock() {
            multicastLock?.takeIf { it.isHeld }?.let { runCatching { it.release() } }
        }

        private val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) = Unit
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) { stop() }
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) = Unit
            override fun onDiscoveryStopped(serviceType: String) = Unit

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                if (!isFlashBackupServiceType(serviceInfo.serviceType)) return
                @Suppress("DEPRECATION")
                nsd.resolveService(serviceInfo, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) = Unit
                    override fun onServiceResolved(info: NsdServiceInfo) {
                        @Suppress("DEPRECATION") val host = info.host?.hostAddress ?: return
                        val device = Device(info.serviceName, info.serviceName, host, info.port)
                        synchronized(devices) {
                            devices[device.id] = device
                            onDevicesChanged(devices.values.toList())
                        }
                    }
                })
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                synchronized(devices) {
                    devices.remove(serviceInfo.serviceName)
                    onDevicesChanged(devices.values.toList())
                }
            }
        }
    }

    class Receiver(private val device: Device, private val pin: String) {
        private val stopped = AtomicBoolean(false)
        @Volatile private var activeSocket: Socket? = null

        fun run(): String {
            require(pin.matches(Regex("\\d{4}"))) { "PIN 必须是四位数字" }
            check(!stopped.get()) { "接收已取消" }
            val socket = Socket()
            activeSocket = socket
            if (stopped.get()) {
                socket.close()
                error("接收已取消")
            }
            return try {
                socket.use {
                    socket.connect(InetSocketAddress(device.host, device.port), SOCKET_TIMEOUT)
                    socket.soTimeout = SOCKET_TIMEOUT
                    socket.getOutputStream().apply {
                        write("$PROTOCOL $pin\n".toByteArray())
                        flush()
                    }
                    val input = socket.getInputStream()
                    val response = readLine(input, 64)
                    if (response == "ERR PIN") error("PIN 不正确")
                    if (!response.startsWith("OK ")) error("发送方返回了无效响应")
                    val size = response.drop(3).toIntOrNull()
                        ?: error("发送方返回了无效响应")
                    require(size in 1..Backup.MAX_FILE_BYTES.toInt()) { "接收的备份文件大小异常" }
                    val bytes = ByteArray(size)
                    var offset = 0
                    while (offset < size) {
                        val count = input.read(bytes, offset, size - offset)
                        if (count < 0) error("连接中断，备份未接收完整")
                        offset += count
                    }
                    Backup.readJson(bytes.inputStream())
                }
            } finally {
                activeSocket = null
            }
        }

        fun stop() {
            if (!stopped.compareAndSet(false, true)) return
            runCatching { activeSocket?.close() }
            activeSocket = null
        }
    }

    private fun readLine(input: InputStream, maxBytes: Int): String {
        val bytes = ArrayList<Byte>(maxBytes)
        while (bytes.size < maxBytes) {
            val value = input.read()
            if (value < 0) error("连接已关闭")
            if (value == '\n'.code) return bytes.toByteArray().toString(Charsets.UTF_8).trimEnd('\r')
            bytes.add(value.toByte())
        }
        error("协议消息过长")
    }
}

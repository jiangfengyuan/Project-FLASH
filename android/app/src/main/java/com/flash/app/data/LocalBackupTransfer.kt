// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
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
            val deadline = System.currentTimeMillis() + SESSION_MILLIS
            var attempts = 0
            try {
                while (!stopped.get() && currentCoroutineContext().isActive &&
                    System.currentTimeMillis() < deadline && attempts < MAX_PIN_ATTEMPTS
                ) {
                    val socket = try {
                        server.accept()
                    } catch (_: SocketTimeoutException) {
                        continue
                    }
                    socket.use { client ->
                        client.soTimeout = SOCKET_TIMEOUT
                        val request = readLine(client.getInputStream(), 64)
                        if (request != "$PROTOCOL $pin") {
                            attempts++
                            client.getOutputStream().apply {
                                write("ERR PIN\n".toByteArray())
                                flush()
                            }
                            return@use
                        }
                        val payload = json.toByteArray(Charsets.UTF_8)
                        client.getOutputStream().apply {
                            write("OK ${payload.size}\n".toByteArray())
                            write(payload)
                            flush()
                        }
                        return true
                    }
                }
                return false
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

    class Discovery(context: Context, private val onDevicesChanged: (List<Device>) -> Unit) {
        private val nsd = context.getSystemService(Context.NSD_SERVICE) as NsdManager
        private val devices = linkedMapOf<String, Device>()
        private var active = false

        fun start() {
            if (active) return
            active = true
            nsd.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
        }

        fun stop() {
            if (!active) return
            active = false
            runCatching { nsd.stopServiceDiscovery(listener) }
            devices.clear()
            onDevicesChanged(emptyList())
        }

        private val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) = Unit
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) { stop() }
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) = Unit
            override fun onDiscoveryStopped(serviceType: String) = Unit

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                if (serviceInfo.serviceType != SERVICE_TYPE) return
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

    fun receive(device: Device, pin: String): String {
        require(pin.matches(Regex("\\d{4}"))) { "PIN 必须是四位数字" }
        Socket().use { socket ->
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
            return String(bytes, Charsets.UTF_8)
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

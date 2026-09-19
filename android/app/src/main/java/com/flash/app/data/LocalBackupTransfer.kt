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
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import java.io.InputStream
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketTimeoutException
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 单次、短时的局域网备份通道。Bonjour/NSD 只负责发现，JSON 通过临时 TCP 连接传输。
 *
 * 握手语义遵循 docs/contracts/lan-handshake-v1.1.md：PIN 不再上链，改为
 * CHALLENGE/proof 挑战应答 + payload HMAC 完整性校验。
 */
object LocalBackupTransfer {
    const val SERVICE_TYPE = "_flashbackup._tcp."
    const val SESSION_MILLIS = 60 * 1000L
    const val TRANSFER_MILLIS = 120 * 1000L
    private const val PROTOCOL = "FLASH-AERO/1"
    private const val CHALLENGE_PREFIX = "CHALLENGE "
    private const val PROOF_DOMAIN = "flash-aero-handshake:"
    private const val MAX_PIN_ATTEMPTS = 5
    private const val SOCKET_TIMEOUT = 15_000
    private const val CHALLENGE_BYTES = 16
    private const val LINE_LIMIT = 64
    // OK 行含 64 字符 HMAC 与 size 字段，必然超过旧的 64 字节行上限。
    private const val OK_LINE_LIMIT = 128
    private val OK_LINE_REGEX = Regex("^OK (\\d+) ([0-9a-f]{64})$")
    private val secureRandom = SecureRandom()

    data class Device(val id: String, val name: String, val host: String, val port: Int)

    fun generatePin(): String = secureRandom.nextInt(1_000_000).toString().padStart(6, '0')

    /**
     * 部分 Android 版本回调的 serviceType 不带末尾 "."，去掉尾点归一后再比较，
     * 避免把合法发现结果静默丢弃。
     */
    internal fun isFlashBackupServiceType(serviceType: String?): Boolean =
        serviceType?.trimEnd('.') == SERVICE_TYPE.trimEnd('.')

    internal fun hmacSha256(key: ByteArray, message: ByteArray): ByteArray =
        Mac.getInstance("HmacSHA256").run {
            init(SecretKeySpec(key, "HmacSHA256"))
            doFinal(message)
        }

    /** proof = hex(HMAC-SHA256(key = PIN ASCII, msg = "flash-aero-handshake:" || nonce))[0:32] */
    internal fun computeProof(pin: String, nonce: ByteArray): ByteArray =
        hmacSha256(pin.toByteArray(Charsets.US_ASCII), PROOF_DOMAIN.toByteArray(Charsets.US_ASCII) + nonce)
            .copyOfRange(0, CHALLENGE_BYTES)

    /** mac = hex(HMAC-SHA256(key = PIN ASCII, msg = payload))，完整 32 字节 */
    internal fun computePayloadMac(pin: String, payload: ByteArray): ByteArray =
        hmacSha256(pin.toByteArray(Charsets.US_ASCII), payload)

    internal fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    /** 严格小写十六进制解码；长度不符或含非法字符返回 null。 */
    internal fun String.hexToBytes(expectedBytes: Int? = null): ByteArray? {
        if (length % 2 != 0) return null
        if (expectedBytes != null && length != expectedBytes * 2) return null
        val result = ByteArray(length / 2)
        for (i in indices step 2) {
            val high = this[i].digitToIntOrNull(16) ?: return null
            val low = this[i + 1].digitToIntOrNull(16) ?: return null
            result[i / 2] = ((high shl 4) or low).toByte()
        }
        return result
    }

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
                serveSession(server, pin, json, isStopped = { stopped.get() })
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
     * 每个连接先发送 CHALLENGE nonce，只有带合法协议头且 proof 校验失败的尝试才计入
     * [MAX_PIN_ATTEMPTS]；格式非法的连接（端口扫描、误连等垃圾流量）直接关闭
     * 且不计数，避免耗尽合法接收方的配对机会。第 1–4 次 proof 失败按 1s/2s/4s/8s
     * 递增延迟后回复 ERR PIN，第 5 次直接断开。独立于此以便脱离 NSD 单测。
     *
     * 单个连接从建立到 payload 写完不得超过 [TRANSFER_MILLIS]，防慢速滴流
     * 长期占用连接槽；超过即结束会话。
     */
    internal suspend fun serveSession(
        server: ServerSocket,
        pin: String,
        json: String,
        isStopped: () -> Boolean,
        failureDelayMillis: (attempt: Int) -> Long = { attempt -> 1000L shl (attempt - 1).coerceIn(0, 3) },
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
            val paired = socket.use { client ->
                client.soTimeout = SOCKET_TIMEOUT
                val transferDeadline = System.currentTimeMillis() + TRANSFER_MILLIS
                try {
                    handleSenderConnection(client, pin, json, transferDeadline) {
                        ++attempts
                        if (attempts >= MAX_PIN_ATTEMPTS) {
                            // 第 5 次失败：计数后断开，不再回复。
                            null
                        } else {
                            delay(failureDelayMillis(attempts))
                            "ERR PIN"
                        }
                    }
                } catch (_: TransferLimitException) {
                    // 传输总时长硬顶已到：慢速滴流占用连接槽，结束整个会话。
                    return false
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (_: Exception) {
                    // 单连接 I/O 或协议错误不拖垮整个会话。
                    false
                }
            }
            if (paired) return true
        }
        return false
    }

    private class TransferLimitException : Exception()

    /**
     * 处理单个发送方侧连接；返回 true 表示配对成功且 payload 已写出。
     * [onProofFailure] 返回要回复的错误行（null 表示直接断开），并负责计数。
     */
    private suspend fun handleSenderConnection(
        client: Socket,
        pin: String,
        json: String,
        transferDeadline: Long,
        onProofFailure: suspend () -> String?,
    ): Boolean {
        val output = client.getOutputStream()
        val input = client.getInputStream()
        val nonce = ByteArray(CHALLENGE_BYTES).also(secureRandom::nextBytes)
        output.write("$CHALLENGE_PREFIX${nonce.toHex()}\n".toByteArray(Charsets.US_ASCII))
        output.flush()

        val request = readLine(input, LINE_LIMIT)
        if (!request.startsWith("$PROTOCOL ")) {
            // 格式非法的请求：不回复、不计数，use 结束时直接关闭连接。
            return false
        }
        val proofBytes = request.substring(PROTOCOL.length + 1).hexToBytes(CHALLENGE_BYTES)
        val expected = computeProof(pin, nonce)
        // proof 格式非法按失败计数（与合法 proof 走同一拒绝路径，不泄露格式信息）。
        if (proofBytes == null || !MessageDigest.isEqual(proofBytes, expected)) {
            val reply = onProofFailure() ?: return false
            runCatching {
                output.write("$reply\n".toByteArray(Charsets.US_ASCII))
                output.flush()
            }
            return false
        }

        val payload = json.toByteArray(Charsets.UTF_8)
        val mac = computePayloadMac(pin, payload).toHex()
        output.write("OK ${payload.size} $mac\n".toByteArray(Charsets.US_ASCII))
        var offset = 0
        while (offset < payload.size) {
            if (System.currentTimeMillis() > transferDeadline) throw TransferLimitException()
            val end = minOf(offset + 16 * 1024, payload.size)
            output.write(payload, offset, end - offset)
            output.flush()
            offset = end
        }
        return true
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
                        // 键改为 host:port：同名伪造/冲突服务按实例并列，不互相顶替。
                        val device = Device("${host}:${info.port}", info.serviceName, host, info.port)
                        synchronized(devices) {
                            devices[device.id] = device
                            onDevicesChanged(devices.values.toList())
                        }
                    }
                })
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                synchronized(devices) {
                    devices.values.removeIf { it.name == serviceInfo.serviceName }
                    onDevicesChanged(devices.values.toList())
                }
            }
        }
    }

    class Receiver(private val device: Device, private val pin: String) {
        private val stopped = AtomicBoolean(false)
        @Volatile private var activeSocket: Socket? = null

        fun run(): String {
            require(pin.matches(Regex("\\d{6}"))) { "PIN 必须是六位数字" }
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
                    val transferDeadline = System.currentTimeMillis() + TRANSFER_MILLIS
                    val input = socket.getInputStream()
                    val output = socket.getOutputStream()

                    val challenge = readLine(input, LINE_LIMIT)
                    if (!challenge.startsWith(CHALLENGE_PREFIX)) error("发送方返回了无效响应")
                    val nonce = challenge.substring(CHALLENGE_PREFIX.length)
                        .hexToBytes(CHALLENGE_BYTES) ?: error("发送方返回了无效响应")
                    val proof = computeProof(pin, nonce).toHex()
                    output.apply {
                        write("$PROTOCOL $proof\n".toByteArray(Charsets.US_ASCII))
                        flush()
                    }

                    val response = readLine(input, OK_LINE_LIMIT)
                    if (response == "ERR PIN") error("PIN 不正确")
                    // 严格整行解析：size 必须纯数字，mac 必须 64 位小写十六进制。
                    val match = OK_LINE_REGEX.matchEntire(response)
                        ?: error("发送方返回了无效响应")
                    val size = match.groupValues[1].toLongOrNull()
                        ?: error("发送方返回了无效响应")
                    if (size < 1 || size > Backup.MAX_FILE_BYTES) {
                        error("接收的备份文件大小异常")
                    }
                    val bytes = ByteArray(size.toInt())
                    var offset = 0
                    while (offset < size) {
                        if (System.currentTimeMillis() > transferDeadline) error("传输超时，备份未接收完整")
                        val count = input.read(bytes, offset, size.toInt() - offset)
                        if (count < 0) error("连接中断，备份未接收完整")
                        offset += count
                    }
                    // 篡改整体丢弃：mac 不等不进入解析/预览。
                    val receivedMac = match.groupValues[2].hexToBytes()
                        ?: error("发送方返回了无效响应")
                    if (!MessageDigest.isEqual(computePayloadMac(pin, bytes), receivedMac)) {
                        error("备份数据校验失败，已整体丢弃")
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

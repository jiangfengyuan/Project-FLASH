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
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import java.io.EOFException
import java.io.IOException
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
 * 握手语义遵循 docs/contracts/lan-handshake-v1.1.md（修正版）：
 * - 发送方（TCP server）持有 payload 并屏幕显示 PIN，必须能证明它知道 PIN；
 * - 接收方（TCP client）输入 PIN、主动连接，先发送 CHALLENGE nonce，
 *   校验发送方回送的 proof 与 payload MAC；PIN 永不上链。
 */
object LocalBackupTransfer {
    const val SERVICE_TYPE = "_flashbackup._tcp."
    const val SESSION_MILLIS = 60 * 1000L
    const val TRANSFER_MILLIS = 120 * 1000L
    private const val PROTOCOL = "FLASH-AERO/1"
    private const val CHALLENGE_PREFIX = "CHALLENGE "
    private const val PROOF_DOMAIN = "flash-aero-handshake:"
    private const val MAX_PROOF_ATTEMPTS = 5
    private const val SOCKET_TIMEOUT = 15_000
    private const val NONCE_BYTES = 16
    private const val LINE_LIMIT = 64
    // OK 行含 64 字符 MAC：3 + size(≤8) + 1 + 64 + 换行 ≈ 76+ 字节，单独放宽，
    // 形态由 OK_LINE_REGEX 严格约束（与 HarmonyOS 参考实现一致取 128）。
    private const val OK_LINE_LIMIT = 128
    private val CHALLENGE_LINE_REGEX = Regex("^CHALLENGE ([0-9a-f]{${NONCE_BYTES * 2}})$")
    private val PROOF_LINE_REGEX = Regex("^$PROTOCOL ([0-9a-f]{32})$")
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

    /**
     * proof = hex(HMAC-SHA256(key = PIN ASCII, msg = "flash-aero-handshake:" + nonceHex ASCII))[0:32]。
     * 注意 HMAC 消息是链上的 32 字符 hex 字符串本身，不是解码后的随机数字节。
     */
    internal fun computeProof(pin: String, nonceHex: String): ByteArray =
        hmacSha256(
            pin.toByteArray(Charsets.US_ASCII),
            (PROOF_DOMAIN + nonceHex).toByteArray(Charsets.US_ASCII),
        ).copyOfRange(0, NONCE_BYTES)

    /** mac = hex(HMAC-SHA256(key = PIN ASCII, msg = payload))，完整 32 字节 / 64 hex 字符 */
    internal fun computePayloadMac(pin: String, payload: ByteArray): ByteArray =
        hmacSha256(pin.toByteArray(Charsets.US_ASCII), payload)

    internal fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }

    private fun randomNonceHex(): String =
        ByteArray(NONCE_BYTES).also(secureRandom::nextBytes).toHex()

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

    private enum class ConnectionOutcome { PAIRED, SESSION_FAILED, CONTINUE }

    /**
     * 在 [server] 上接受连接，直到配对成功、被取消或 [SESSION_MILLIS] 会话超时。
     *
     * 发送方每连接只服务 CHALLENGE/proof 应答：收到合法 `CHALLENGE <nonceHex>` 即回送
     * `FLASH-AERO/1 <proof>` + `OK <size> <mac>` + payload（流水线）；每连接最多应答
     * [MAX_PROOF_ATTEMPTS] 次。收到 `ERR PIN`（校验方已计满 5 次失败）或应答写出失败即
     * 结束会话；畸形流量与空闲连接静默关闭、不结束会话。独立于此以便脱离 NSD 单测。
     *
     * 单个连接从建立到 payload 写完不得超过 [TRANSFER_MILLIS]，防慢速滴流
     * 长期占用连接槽；超过即结束会话。
     */
    internal suspend fun serveSession(
        server: ServerSocket,
        pin: String,
        json: String,
        isStopped: () -> Boolean,
    ): Boolean {
        val deadline = System.currentTimeMillis() + SESSION_MILLIS
        val payload = json.toByteArray(Charsets.UTF_8)
        val mac = computePayloadMac(pin, payload).toHex()
        while (!isStopped() && currentCoroutineContext().isActive &&
            System.currentTimeMillis() < deadline
        ) {
            val socket = try {
                server.accept()
            } catch (_: SocketTimeoutException) {
                continue
            }
            when (socket.use { handleSenderConnection(it, pin, payload, mac) }) {
                ConnectionOutcome.PAIRED -> return true
                ConnectionOutcome.SESSION_FAILED -> return false
                ConnectionOutcome.CONTINUE -> Unit
            }
        }
        return false
    }

    private class TransferLimitException : IOException()
    private class LineTooLongException : IOException()

    /**
     * 服务单个发送方侧连接：应答 CHALLENGE，直至对端关闭（配对成功 / ERR PIN）、
     * 超限或出错。返回该连接的结局以决定会话走向。
     */
    private fun handleSenderConnection(
        client: Socket,
        pin: String,
        payload: ByteArray,
        payloadMacHex: String,
    ): ConnectionOutcome {
        client.soTimeout = SOCKET_TIMEOUT
        val transferDeadline = System.currentTimeMillis() + TRANSFER_MILLIS
        val input = client.getInputStream()
        val output = client.getOutputStream()
        var challenges = 0
        var answered = false
        var rejected = false
        return try {
            while (true) {
                val line = try {
                    readLine(input, LINE_LIMIT)
                } catch (_: EOFException) {
                    break // 对端关闭：按已发生的事实判定结局
                }
                when {
                    line == "ERR PIN" -> rejected = true
                    else -> {
                        val challenge = CHALLENGE_LINE_REGEX.matchEntire(line)
                            ?: return ConnectionOutcome.CONTINUE // 畸形流量：静默关闭、不结束会话
                        challenges++
                        if (challenges > MAX_PROOF_ATTEMPTS) {
                            // 校验方预算内不应再来第 6 个挑战：关闭本连接，会话继续。
                            return ConnectionOutcome.CONTINUE
                        }
                        val proof = computeProof(pin, challenge.groupValues[1]).toHex()
                        writeAnswer(output, proof, payload, payloadMacHex, transferDeadline)
                        answered = true
                    }
                }
            }
            when {
                answered && !rejected -> ConnectionOutcome.PAIRED
                rejected -> ConnectionOutcome.SESSION_FAILED
                else -> ConnectionOutcome.CONTINUE
            }
        } catch (_: SocketTimeoutException) {
            // 空闲超时：连接静默关闭，配对会话保留。
            ConnectionOutcome.CONTINUE
        } catch (_: LineTooLongException) {
            // 畸形流量（行超长）：连接静默关闭，配对会话保留。
            ConnectionOutcome.CONTINUE
        } catch (_: TransferLimitException) {
            // 传输总时长硬顶已到：慢速滴流占用连接槽，结束整个会话。
            ConnectionOutcome.SESSION_FAILED
        } catch (_: IOException) {
            // 应答写出失败等 I/O 错误：结束会话（对照参考实现 finish(false)）。
            ConnectionOutcome.SESSION_FAILED
        }
    }

    /** 按规格顺序流水线写出 proof 行、OK 头行与 payload，受 [transferDeadline] 约束。 */
    private fun writeAnswer(
        output: java.io.OutputStream,
        proof: String,
        payload: ByteArray,
        payloadMacHex: String,
        transferDeadline: Long,
    ) {
        output.write("$PROTOCOL $proof\n".toByteArray(Charsets.US_ASCII))
        output.write("OK ${payload.size} $payloadMacHex\n".toByteArray(Charsets.US_ASCII))
        var offset = 0
        while (offset < payload.size) {
            if (System.currentTimeMillis() > transferDeadline) throw TransferLimitException()
            val end = minOf(offset + 16 * 1024, payload.size)
            output.write(payload, offset, end - offset)
            output.flush()
            offset = end
        }
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

    /**
     * 接收方：主动连接发送设备，发送 CHALLENGE 并校验回送的 proof。
     *
     * [pinProvider] 在每次校验 proof 时重新读取，回退窗口内用户修正 PIN 可生效。
     * [proofBackoffMillis] 为第 1–4 次 proof 失败后的重挑战延迟（默认 1/2/4/8s），
     * 第 5 次失败发送 ERR PIN 并断开。
     */
    class Receiver(
        private val device: Device,
        private val pinProvider: () -> String,
        private val proofBackoffMillis: (attempt: Int) -> Long =
            { attempt -> 1000L shl (attempt - 1).coerceIn(0, 3) },
    ) {
        constructor(device: Device, pin: String) : this(device, { pin })

        private val stopped = AtomicBoolean(false)
        @Volatile private var activeSocket: Socket? = null

        fun run(): String {
            require(pinProvider().matches(Regex("\\d{6}"))) { "PIN 必须是六位数字" }
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

                    var nonceHex = randomNonceHex()
                    output.apply {
                        write("$CHALLENGE_PREFIX$nonceHex\n".toByteArray(Charsets.US_ASCII))
                        flush()
                    }
                    var failedProofs = 0
                    while (true) {
                        // 1) proof 行：严格格式 + 常数时间比较
                        val proofLine = readLine(input, LINE_LIMIT)
                        val proof = PROOF_LINE_REGEX.matchEntire(proofLine)
                            ?: error("发送方返回了无效响应")
                        val expectedProof = computeProof(pinProvider(), nonceHex).toHex()
                        val receivedProof = proof.groupValues[1]
                        if (!MessageDigest.isEqual(
                                expectedProof.toByteArray(Charsets.US_ASCII),
                                receivedProof.toByteArray(Charsets.US_ASCII),
                            )
                        ) {
                            failedProofs++
                            if (failedProofs >= MAX_PROOF_ATTEMPTS) {
                                // 第 5 次失败：通知发送方并断开该连接。
                                runCatching {
                                    output.write("ERR PIN\n".toByteArray(Charsets.US_ASCII))
                                    output.flush()
                                }
                                error("PIN 不正确")
                            }
                            // 丢弃被否应答的流水线尾部（OK 头行 + size 字节）后重挑战。
                            drainRejectedAnswer(input, transferDeadline)
                            val backoff = proofBackoffMillis(failedProofs)
                            if (backoff > 0) Thread.sleep(backoff)
                            if (System.currentTimeMillis() > transferDeadline) {
                                error("传输超时，备份未接收完整")
                            }
                            nonceHex = randomNonceHex()
                            output.apply {
                                write("$CHALLENGE_PREFIX$nonceHex\n".toByteArray(Charsets.US_ASCII))
                                flush()
                            }
                            continue
                        }
                        val authenticatedPin = pinProvider()

                        // 2) OK 头行：严格整行解析
                        val response = readLine(input, OK_LINE_LIMIT)
                        val header = OK_LINE_REGEX.matchEntire(response)
                            ?: error("发送方返回了无效响应")
                        val size = header.groupValues[1].toLongOrNull()
                            ?: error("接收的备份文件大小异常")
                        if (size < 1 || size > Backup.MAX_FILE_BYTES) {
                            error("接收的备份文件大小异常")
                        }

                        // 3) payload：读满 size 字节后先验 MAC，篡改整体丢弃
                        val bytes = ByteArray(size.toInt())
                        var offset = 0
                        while (offset < size) {
                            if (System.currentTimeMillis() > transferDeadline) {
                                error("传输超时，备份未接收完整")
                            }
                            val count = input.read(bytes, offset, size.toInt() - offset)
                            if (count < 0) error("连接中断，备份未接收完整")
                            offset += count
                        }
                        val computedMac = computePayloadMac(authenticatedPin, bytes).toHex()
                        if (!MessageDigest.isEqual(
                                computedMac.toByteArray(Charsets.US_ASCII),
                                header.groupValues[2].toByteArray(Charsets.US_ASCII),
                            )
                        ) {
                            error("接收的数据校验失败，已整体丢弃")
                        }
                        return@use Backup.readJson(bytes.inputStream())
                    }
                    @Suppress("UNREACHABLE_CODE")
                    error("unreachable")
                }
            } finally {
                activeSocket = null
            }
        }

        /** 丢弃一个被否决的应答尾部：OK 头行须合法，随后逐块排空其声明的 payload。 */
        private fun drainRejectedAnswer(input: InputStream, transferDeadline: Long) {
            val discarded = OK_LINE_REGEX.matchEntire(readLine(input, OK_LINE_LIMIT))
                ?: error("发送方返回了无效响应")
            val size = discarded.groupValues[1].toLongOrNull()
                ?: error("接收的备份文件大小异常")
            var remaining = size
            val buffer = ByteArray(8192)
            while (remaining > 0) {
                if (System.currentTimeMillis() > transferDeadline) {
                    error("传输超时，备份未接收完整")
                }
                val count = input.read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt())
                if (count < 0) error("连接中断，备份未接收完整")
                remaining -= count
            }
        }

        fun stop() {
            if (!stopped.compareAndSet(false, true)) return
            runCatching { activeSocket?.close() }
            activeSocket = null
        }
    }

    /** 按行读取（LF 结尾、容忍 CR）；EOF 抛 [EOFException]，超限抛 [IOException]。 */
    private fun readLine(input: InputStream, maxBytes: Int): String {
        val bytes = ArrayList<Byte>(maxBytes)
        while (bytes.size < maxBytes) {
            val value = input.read()
            if (value < 0) throw EOFException("连接已关闭")
            if (value == '\n'.code) return bytes.toByteArray().toString(Charsets.UTF_8).trimEnd('\r')
            bytes.add(value.toByte())
        }
        throw LineTooLongException()
    }
}

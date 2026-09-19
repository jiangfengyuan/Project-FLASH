// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import java.net.ServerSocket
import java.net.Socket
import java.security.SecureRandom
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutionException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class LocalBackupTransferTest {
    private val pin = "123456"

    companion object {
        private const val SPEC_NONCE = "00112233445566778899aabbccddeeff"
    }

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }

    private fun readLineRaw(input: java.io.InputStream): String {
        val bytes = ArrayList<Byte>()
        while (true) {
            val value = input.read()
            if (value < 0) error("连接已关闭")
            if (value == '\n'.code) return bytes.toByteArray().toString(Charsets.UTF_8).trimEnd('\r')
            bytes.add(value.toByte())
        }
    }

    private fun readN(input: java.io.InputStream, size: Int): ByteArray {
        val bytes = ByteArray(size)
        var offset = 0
        while (offset < size) {
            val count = input.read(bytes, offset, size - offset)
            if (count < 0) error("连接已关闭")
            offset += count
        }
        return bytes
    }

    @Test
    fun `generated PIN is always six digits`() {
        repeat(200) {
            assertTrue(LocalBackupTransfer.generatePin().matches(Regex("\\d{6}")))
        }
    }

    @Test
    fun `proof matches spec test vector`() {
        // lan-handshake-v1.1: msg = ASCII("flash-aero-handshake:" + nonceHex 字符串本身)
        val proof = with(LocalBackupTransfer) { computeProof("123456", "00112233445566778899aabbccddeeff").toHex() }
        assertEquals("bc2889b1353c82a918d17c6ba785ed3e", proof)
    }

    @Test
    fun `payload mac matches spec test vector`() {
        val mac = with(LocalBackupTransfer) {
            computePayloadMac("123456", "{}".toByteArray(Charsets.UTF_8)).toHex()
        }
        assertEquals("eb95f4b6e98d2c8f6484947d07b70cd726474ca9dda165359f7b6546406a7e42", mac)
    }

    @Test
    fun `service type matches regardless of trailing dot`() {
        assertTrue(LocalBackupTransfer.isFlashBackupServiceType("_flashbackup._tcp."))
        // 部分 Android 版本回调不带末尾 "."
        assertTrue(LocalBackupTransfer.isFlashBackupServiceType("_flashbackup._tcp"))
        assertTrue(LocalBackupTransfer.isFlashBackupServiceType(LocalBackupTransfer.SERVICE_TYPE))
        assertFalse(LocalBackupTransfer.isFlashBackupServiceType("_other._tcp."))
        assertFalse(LocalBackupTransfer.isFlashBackupServiceType("_flashbackup._udp."))
        assertFalse(LocalBackupTransfer.isFlashBackupServiceType(null))
    }

    // ---------- 发送方（server 侧）：应答 CHALLENGE ----------

    @Test
    fun `sender answers challenge with spec proof and pipelined payload`() {
        val server = ServerSocket(0).apply { soTimeout = 100 }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val session = executor.submitSession(server, pin)
            Socket("127.0.0.1", server.localPort).use { socket ->
                socket.soTimeout = 5_000
                // 接收方驱动：客户端发 CHALLENGE，服务端回 proof + OK + payload
                assertEquals("FLASH-AERO/1 bc2889b1353c82a918d17c6ba785ed3e", challengeRound(socket, SPEC_NONCE, pin))
                // 消费完成后关闭连接，服务端判定配对成功
                socket.shutdownOutput()
                socket.getInputStream().readBytes()
            }
            assertTrue(session.get(5, TimeUnit.SECONDS))
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun `garbage reversed-direction and malformed lines do not end the session`() {
        val server = ServerSocket(0).apply { soTimeout = 100 }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val session = executor.submitSession(server, pin)
            // 垃圾流量（已远超 5 次上限）不得结束会话，也不得到任何应答
            repeat(6) { assertEquals("", exchangeGarbage(server.localPort, "garbage $it")) }
            // 方向反置：旧方向由“客户端”自证 proof——新方向下服务端不应应答
            assertEquals("", exchangeGarbage(server.localPort, "FLASH-AERO/1 bc2889b1353c82a918d17c6ba785ed3e"))
            // 非法 nonce：非 hex / 大写 hex / 行超长，一律静默关闭
            assertEquals("", exchangeGarbage(server.localPort, "CHALLENGE not-a-nonce"))
            assertEquals("", exchangeGarbage(server.localPort, "CHALLENGE 00112233445566778899AABBCCDDEEFF"))
            assertEquals("", exchangeGarbage(server.localPort, "CHALLENGE " + "ab".repeat(40)))
            Socket("127.0.0.1", server.localPort).use { socket ->
                socket.soTimeout = 5_000
                challengeRound(socket, SPEC_NONCE, pin)
                socket.shutdownOutput()
                socket.getInputStream().readBytes()
            }
            assertTrue(session.get(5, TimeUnit.SECONDS))
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun `sender serves at most five challenges per connection`() {
        val server = ServerSocket(0).apply { soTimeout = 100 }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val session = executor.submitSession(server, pin)
            Socket("127.0.0.1", server.localPort).use { socket ->
                socket.soTimeout = 5_000
                val nonces = mutableListOf<String>()
                repeat(5) {
                    val nonce = ByteArray(16).also(SecureRandom()::nextBytes).toHex()
                    nonces.add(nonce)
                    challengeRound(socket, nonce, pin)
                }
                // 第 6 个挑战超出单连接应答预算：静默断开
                socket.getOutputStream().apply {
                    write("CHALLENGE ${ByteArray(16).also(SecureRandom()::nextBytes).toHex()}\n".toByteArray())
                    flush()
                }
                assertThrows(Exception::class.java) { readLineRaw(socket.getInputStream()) }
            }
            // 会话未被第 6 个挑战拖垮：新连接仍可配对
            Socket("127.0.0.1", server.localPort).use { socket ->
                socket.soTimeout = 5_000
                challengeRound(socket, SPEC_NONCE, pin)
                socket.shutdownOutput()
                socket.getInputStream().readBytes()
            }
            assertTrue(session.get(5, TimeUnit.SECONDS))
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun `ERR PIN from verifier ends the session as failure`() {
        val server = ServerSocket(0).apply { soTimeout = 100 }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val session = executor.submitSession(server, pin)
            Socket("127.0.0.1", server.localPort).use { socket ->
                socket.soTimeout = 5_000
                challengeRound(socket, SPEC_NONCE, pin)
                socket.getOutputStream().apply {
                    write("ERR PIN\n".toByteArray())
                    flush()
                }
            }
            assertFalse(session.get(5, TimeUnit.SECONDS))
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    // ---------- 接收方（client 侧）：发送 CHALLENGE 并校验 ----------

    @Test
    fun `receiver accepts valid proof and returns the payload`() {
        val payload = """{"version":"flash-backup-v2"}"""
        val payloadBytes = payload.toByteArray(Charsets.UTF_8)
        val (server, future) = scriptedSender(pin, payloadBytes)
        try {
            val receiver = receiverFor(server)
            assertEquals(payload, receiver.run())
            future.get(2, TimeUnit.SECONDS)
        } finally {
            server.close()
        }
    }

    @Test
    fun `receiver re-challenges with a fresh nonce after a wrong proof`() {
        val payload = """{"version":"flash-backup-v2"}"""
        val payloadBytes = payload.toByteArray(Charsets.UTF_8)
        val seenNonces = mutableListOf<String>()
        val (server, future) = scriptedSender(pin, payloadBytes, rounds = 2) { nonce, round, output ->
            seenNonces.add(nonce)
            // 第 1 轮用错误 PIN 计算 proof；第 2 轮用正确 PIN + 服务端看到的第 2 个 nonce
            answer(output, pin, payloadBytes, nonce, proofPin = if (round == 0) "000000" else pin)
        }
        try {
            val receiver = receiverFor(server)
            assertEquals(payload, receiver.run())
            future.get(2, TimeUnit.SECONDS)
            assertEquals(2, seenNonces.size)
            assertNotEquals(seenNonces[0], seenNonces[1])
        } finally {
            server.close()
        }
    }

    @Test
    fun `receiver gives up after five wrong proofs and sends ERR PIN`() {
        val payloadBytes = "{}".toByteArray(Charsets.UTF_8)
        val (server, future) = scriptedSender(pin, payloadBytes, rounds = 5, expectErrPin = true) { nonce, _, output ->
            answer(output, pin, payloadBytes, nonce, proofPin = "000000")
        }
        try {
            val receiver = receiverFor(server)
            val error = assertThrows(Exception::class.java) { receiver.run() }
            assertEquals("PIN 不正确", error.message)
            future.get(2, TimeUnit.SECONDS)
        } finally {
            server.close()
        }
    }

    @Test
    fun `receiver discards the whole payload when the mac is tampered`() {
        val payload = """{"version":"flash-backup-v2"}"""
        val payloadBytes = payload.toByteArray(Charsets.UTF_8)
        val (server, _) = scriptedSender(pin, payloadBytes) { nonce, _, output ->
            answer(output, pin, payloadBytes, nonce, okLine = "OK ${payloadBytes.size} ${"0".repeat(64)}")
        }
        try {
            val receiver = receiverFor(server)
            val error = assertThrows(Exception::class.java) { receiver.run() }
            assertEquals("接收的数据校验失败，已整体丢弃", error.message)
        } finally {
            server.close()
        }
    }

    @Test
    fun `receiver rejects malformed OK lines strictly`() {
        val payloadBytes = "{}".toByteArray(Charsets.UTF_8)
        val mac = with(LocalBackupTransfer) { computePayloadMac(pin, payloadBytes).toHex() }
        // OK 行必须严格为 "OK <纯十进制 size> <64 位小写 hex mac>"
        val malformedLines = listOf(
            "OK 123abc $mac",              // size 含尾随字符
            "OK 12",                        // 缺少 mac
            "OK 12 ${mac.take(62)}",       // mac 过短
            "OK 12 ${mac.uppercase()}",    // mac 非小写
            "OK 12 $mac trailing",         // 行尾多余内容
            "OK 12  $mac",                 // 双空格
        )
        for (badOk in malformedLines) {
            val (server, _) = scriptedSender(pin, payloadBytes) { nonce, _, output ->
                answer(output, pin, payloadBytes, nonce, okLine = badOk)
            }
            try {
                val receiver = receiverFor(server)
                val error = assertThrows(Exception::class.java) { receiver.run() }
                assertEquals("发送方返回了无效响应", error.message)
            } finally {
                server.close()
            }
        }
    }

    @Test
    fun `receiver rejects oversized size`() {
        val payloadBytes = "{}".toByteArray(Charsets.UTF_8)
        val mac = with(LocalBackupTransfer) { computePayloadMac(pin, payloadBytes).toHex() }
        val (server, _) = scriptedSender(pin, payloadBytes) { nonce, _, output ->
            answer(output, pin, payloadBytes, nonce, okLine = "OK 99999999999999999999 $mac")
        }
        try {
            val receiver = receiverFor(server)
            val error = assertThrows(Exception::class.java) { receiver.run() }
            assertEquals("接收的备份文件大小异常", error.message)
        } finally {
            server.close()
        }
    }

    @Test
    fun `receiver rejects malformed proof lines`() {
        val payloadBytes = "{}".toByteArray(Charsets.UTF_8)
        val (server, _) = scriptedSender(pin, payloadBytes) { _, _, output ->
            output.write("FLASH-AERO/1 not-a-proof\n".toByteArray(Charsets.US_ASCII))
        }
        try {
            val receiver = receiverFor(server)
            val error = assertThrows(Exception::class.java) { receiver.run() }
            assertEquals("发送方返回了无效响应", error.message)
        } finally {
            server.close()
        }
    }

    @Test
    fun `receiver rejects malformed OK line while draining a rejected answer`() {
        val payloadBytes = "{}".toByteArray(Charsets.UTF_8)
        val (server, _) = scriptedSender(pin, payloadBytes) { nonce, _, output ->
            answer(output, pin, payloadBytes, nonce, okLine = "OK 123abc", proofPin = "000000")
        }
        try {
            val receiver = receiverFor(server)
            val error = assertThrows(Exception::class.java) { receiver.run() }
            assertEquals("发送方返回了无效响应", error.message)
        } finally {
            server.close()
        }
    }

    @Test
    fun `receiver requires a six digit pin`() {
        val receiver = LocalBackupTransfer.Receiver(
            LocalBackupTransfer.Device("test", "test", "127.0.0.1", 1),
            { "1234" },
        )
        assertThrows(IllegalArgumentException::class.java) { receiver.run() }
    }

    @Test
    fun `receiver stop closes an in-flight connection`() {
        val server = ServerSocket(0)
        val challengeReceived = CountDownLatch(1)
        val executor = Executors.newFixedThreadPool(2)
        try {
            val serverTask = executor.submit {
                server.accept().use { socket ->
                    readLineRaw(socket.getInputStream()) // CHALLENGE
                    challengeReceived.countDown()
                    // 挂起直到客户端断开
                    while (socket.getInputStream().read() >= 0) Unit
                }
            }
            val receiver = receiverFor(server)
            val receiveTask = executor.submit<String> { receiver.run() }

            assertTrue(challengeReceived.await(2, TimeUnit.SECONDS))
            receiver.stop()

            assertThrows(ExecutionException::class.java) {
                receiveTask.get(2, TimeUnit.SECONDS)
            }
            serverTask.get(2, TimeUnit.SECONDS)
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    // ---------- 测试辅助 ----------

    private fun receiverFor(server: ServerSocket) = LocalBackupTransfer.Receiver(
        LocalBackupTransfer.Device("test", "test", "127.0.0.1", server.localPort),
        { pin },
        proofBackoffMillis = { 0 },
    )

    private fun ExecutorService.submitSession(
        server: ServerSocket,
        pin: String,
        json: String = "{}",
    ): Future<Boolean> = submit<Boolean> {
        runBlocking {
            LocalBackupTransfer.serveSession(server, pin, json, isStopped = { false })
        }
    }

    /**
     * 接收方侧的一轮完整握手：发 CHALLENGE，校验服务端回送的 proof 行、OK 行与 payload，
     * 并返回 proof 行。校验失败即断言错误（测试主线程可见）。
     */
    private fun challengeRound(socket: Socket, nonceHex: String, expectedPin: String): String {
        val payload = "{}"
        socket.getOutputStream().apply {
            write("CHALLENGE $nonceHex\n".toByteArray(Charsets.US_ASCII))
            flush()
        }
        val input = socket.getInputStream()
        val proofLine = readLineRaw(input)
        val expectedProof = with(LocalBackupTransfer) { computeProof(expectedPin, nonceHex).toHex() }
        assertEquals("FLASH-AERO/1 $expectedProof", proofLine)
        val expectedMac = with(LocalBackupTransfer) {
            computePayloadMac(expectedPin, payload.toByteArray(Charsets.UTF_8)).toHex()
        }
        assertEquals("OK ${payload.toByteArray(Charsets.UTF_8).size} $expectedMac", readLineRaw(input))
        assertEquals(payload, readN(input, payload.toByteArray(Charsets.UTF_8).size).toString(Charsets.UTF_8))
        return proofLine
    }

    /** 连接后发送一行畸形/方向反置数据，并读取服务端关闭前的全部响应（应为空）。 */
    private fun exchangeGarbage(port: Int, line: String): String =
        try {
            Socket("127.0.0.1", port).use { socket ->
                socket.soTimeout = 5_000
                socket.getOutputStream().apply {
                    write("$line\n".toByteArray(Charsets.UTF_8))
                    flush()
                }
                socket.getInputStream().readBytes().toString(Charsets.UTF_8)
            }
        } catch (reset: java.net.SocketException) {
            // 行超长的用例里服务端在仍有未读数据时关闭，内核以 RST 代替 FIN；
            // 对畸形流量而言“连接被静默丢弃”即符合预期。
            ""
        }

    /**
     * 启动一个符合 lan-handshake-v1.1 的伪发送服务器：读取客户端 CHALLENGE
     * （锁定挑战行格式与每轮新 nonce），按 [onChallenge] 应答（默认正确 proof +
     * 合法 OK 行 + payload 流水线）。
     */
    private fun scriptedSender(
        pin: String,
        payload: ByteArray,
        rounds: Int = 1,
        expectErrPin: Boolean = false,
        onChallenge: (nonce: String, round: Int, output: java.io.OutputStream) -> Unit =
            { nonce, _, output -> answer(output, pin, payload, nonce) },
    ): Pair<ServerSocket, Future<*>> {
        val server = ServerSocket(0)
        val future = Executors.newSingleThreadExecutor().submit {
            try {
                server.accept().use { socket ->
                    socket.soTimeout = 5_000
                    val input = socket.getInputStream()
                    val output = socket.getOutputStream()
                    for (round in 0 until rounds) {
                        val line = readLineRaw(input)
                        val match = Regex("^CHALLENGE ([0-9a-f]{32})$").matchEntire(line)
                            ?: throw IllegalStateException("非法挑战行：$line")
                        onChallenge(match.groupValues[1], round, output)
                        output.flush()
                    }
                    if (expectErrPin) {
                        assertEquals("ERR PIN", readLineRaw(input))
                    }
                }
            } catch (_: Exception) {
                // 客户端提前断开等场景直接忽略，断言在测试主线程完成。
            }
        }
        return server to future
    }

    /** 按规格顺序流水线写出一轮应答：proof 行、OK 行（可覆盖为畸形）、payload。 */
    private fun answer(
        output: java.io.OutputStream,
        pin: String,
        payload: ByteArray,
        nonceHex: String,
        okLine: String? = null,
        proofPin: String? = null,
    ) {
        val proof = with(LocalBackupTransfer) { computeProof(proofPin ?: pin, nonceHex).toHex() }
        val mac = with(LocalBackupTransfer) { computePayloadMac(pin, payload).toHex() }
        output.write("FLASH-AERO/1 $proof\n".toByteArray(Charsets.US_ASCII))
        output.write("${okLine ?: "OK ${payload.size} $mac"}\n".toByteArray(Charsets.US_ASCII))
        output.write(payload)
    }
}

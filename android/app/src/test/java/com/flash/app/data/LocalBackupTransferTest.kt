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
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class LocalBackupTransferTest {
    private val hexChars = "0123456789abcdef".toCharArray()

    private fun ByteArray.toHex(): String = joinToString("") {
        "${hexChars[it.toInt() shr 4 and 0xf]}${hexChars[it.toInt() and 0xf]}"
    }

    private fun String.hexToBytes(): ByteArray {
        require(length % 2 == 0)
        return ByteArray(length / 2) { i ->
            ((this[i * 2].digitToInt(16) shl 4) or this[i * 2 + 1].digitToInt(16)).toByte()
        }
    }

    private fun readLineRaw(input: java.io.InputStream): String {
        val bytes = ArrayList<Byte>()
        while (true) {
            val value = input.read()
            if (value < 0) error("连接已关闭")
            if (value == '\n'.code) return bytes.toByteArray().toString(Charsets.UTF_8).trimEnd('\r')
            bytes.add(value.toByte())
        }
    }

    @Test
    fun `generated PIN is always six digits`() {
        repeat(200) {
            assertTrue(LocalBackupTransfer.generatePin().matches(Regex("\\d{6}")))
        }
    }

    @Test
    fun `proof matches spec test vector`() {
        // lan-handshake-v1.1: HMAC-SHA256(key="123456" ASCII, msg="flash-aero-handshake:" || nonce)[0:32]
        val nonce = "00112233445566778899aabbccddeeff".hexToBytes()
        val proof = with(LocalBackupTransfer) { computeProof("123456", nonce).toHex() }
        assertEquals("f5d240c6033dd86a1c91055838af3e00", proof)
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

    @Test
    fun `garbage connections do not consume proof attempts`() {
        val server = ServerSocket(0).apply { soTimeout = 100 }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val session = executor.submitSession(server, pin = "123456")
            // 6 个格式非法的连接（已超 5 次上限）不应消耗任何尝试次数，也不应得到回复
            repeat(6) { assertEquals("", exchangeRaw(server.localPort, "garbage $it")) }
            // 协议头合法但 proof 错误：计数并回复 ERR PIN
            repeat(4) { assertEquals("ERR PIN\n", exchangeProof(server.localPort, "123456", proofPin = "999999")) }
            // 若垃圾连接也计数，会话早已因到达 5 次上限而关闭
            val payload = "{}"
            val mac = with(LocalBackupTransfer) {
                computePayloadMac("123456", payload.toByteArray(Charsets.UTF_8)).toHex()
            }
            assertEquals(
                "OK 2 $mac\n$payload",
                exchangeProof(server.localPort, "123456", proofPin = "123456"),
            )
            assertTrue(session.get(5, TimeUnit.SECONDS))
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun `session closes after five well-formed wrong proof attempts`() {
        val server = ServerSocket(0).apply { soTimeout = 100 }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val session = executor.submitSession(server, pin = "123456")
            // 前 4 次失败回复 ERR PIN；第 5 次失败只计数并断开，不再回复
            repeat(4) { assertEquals("ERR PIN\n", exchangeProof(server.localPort, "123456", proofPin = "000000")) }
            assertEquals("", exchangeProof(server.localPort, "123456", proofPin = "000000"))
            assertFalse(session.get(5, TimeUnit.SECONDS))
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun `syntactically invalid proof still counts as a failed attempt`() {
        val server = ServerSocket(0).apply { soTimeout = 100 }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val session = executor.submitSession(server, pin = "123456")
            // 非十六进制 proof 无法与期望 proof 相等，按失败计数（走同一拒绝路径）
            repeat(4) { assertEquals("ERR PIN\n", exchangeRaw(server.localPort, "FLASH-AERO/1 not-a-proof")) }
            val payload = "{}"
            val mac = with(LocalBackupTransfer) {
                computePayloadMac("123456", payload.toByteArray(Charsets.UTF_8)).toHex()
            }
            assertEquals(
                "OK 2 $mac\n$payload",
                exchangeProof(server.localPort, "123456", proofPin = "123456"),
            )
            assertTrue(session.get(5, TimeUnit.SECONDS))
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun `protocol header without proof does not count as an attempt`() {
        val server = ServerSocket(0).apply { soTimeout = 100 }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val session = executor.submitSession(server, pin = "123456")
            // 仅协议头、缺少 proof 的请求视为格式非法：不计数、不回复
            repeat(6) { assertEquals("", exchangeRaw(server.localPort, "FLASH-AERO/1")) }
            val payload = "{}"
            val mac = with(LocalBackupTransfer) {
                computePayloadMac("123456", payload.toByteArray(Charsets.UTF_8)).toHex()
            }
            assertEquals(
                "OK 2 $mac\n$payload",
                exchangeProof(server.localPort, "123456", proofPin = "123456"),
            )
            assertTrue(session.get(5, TimeUnit.SECONDS))
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun `receiver accepts a valid mac and returns the payload`() {
        val payload = """{"version":"flash-backup-v2"}"""
        val server = scriptedServer(pin = "123456", payload = payload.toByteArray(Charsets.UTF_8))
        try {
            val receiver = LocalBackupTransfer.Receiver(testDevice(server), "123456")
            assertEquals(payload, receiver.run())
        } finally {
            server.close()
        }
    }

    @Test
    fun `receiver discards the whole payload when the mac is tampered`() {
        val payload = """{"version":"flash-backup-v2"}"""
        val server = scriptedServer(
            pin = "123456",
            payload = payload.toByteArray(Charsets.UTF_8),
            responseLine = "OK ${payload.length} ${"0".repeat(64)}",
        )
        try {
            val receiver = LocalBackupTransfer.Receiver(testDevice(server), "123456")
            val error = assertThrows(Exception::class.java) { receiver.run() }
            assertEquals("备份数据校验失败，已整体丢弃", error.message)
        } finally {
            server.close()
        }
    }

    @Test
    fun `receiver rejects malformed OK lines strictly`() {
        val payload = "{}"
        val mac = with(LocalBackupTransfer) {
            computePayloadMac("123456", payload.toByteArray(Charsets.UTF_8)).toHex()
        }
        // OK 行必须严格为 "OK <纯十进制 size> <64 位小写 hex mac>"
        val malformedLines = listOf(
            "OK 123abc $mac",                  // size 含尾随字符
            "OK 12",                            // 缺少 mac
            "OK 12 ${mac.take(62)}",           // mac 过短
            "OK 12 ${mac.uppercase()}",        // mac 非小写
            "OK 12 $mac trailing",             // 行尾多余内容
            "OK 12  $mac",                     // 双空格
        )
        for (line in malformedLines) {
            val server = scriptedServer(
                pin = "123456",
                payload = payload.toByteArray(Charsets.UTF_8),
                responseLine = line,
            )
            try {
                val receiver = LocalBackupTransfer.Receiver(testDevice(server), "123456")
                val error = assertThrows(Exception::class.java) { receiver.run() }
                assertEquals("发送方返回了无效响应", error.message)
            } finally {
                server.close()
            }
        }
    }

    @Test
    fun `receiver surfaces ERR PIN from the sender`() {
        val server = scriptedServer(
            pin = "123456",
            payload = "{}".toByteArray(Charsets.UTF_8),
            responseLine = "ERR PIN",
        )
        try {
            val receiver = LocalBackupTransfer.Receiver(testDevice(server), "123456")
            val error = assertThrows(Exception::class.java) { receiver.run() }
            assertEquals("PIN 不正确", error.message)
        } finally {
            server.close()
        }
    }

    @Test
    fun `receiver rejects a non-numeric oversized size`() {
        val payload = "{}"
        val mac = with(LocalBackupTransfer) {
            computePayloadMac("123456", payload.toByteArray(Charsets.UTF_8)).toHex()
        }
        val server = scriptedServer(
            pin = "123456",
            payload = payload.toByteArray(Charsets.UTF_8),
            responseLine = "OK 99999999999999999999 $mac",
        )
        try {
            val receiver = LocalBackupTransfer.Receiver(testDevice(server), "123456")
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
            "1234",
        )
        assertThrows(IllegalArgumentException::class.java) { receiver.run() }
    }

    @Test
    fun `receiver stop closes an in-flight connection`() {
        val server = ServerSocket(0)
        val proofReceived = CountDownLatch(1)
        val executor = Executors.newFixedThreadPool(2)
        try {
            val serverTask = executor.submit {
                server.accept().use { socket ->
                    val output = socket.getOutputStream()
                    val nonce = ByteArray(16).also(SecureRandom()::nextBytes)
                    output.apply {
                        write("CHALLENGE ${nonce.toHex()}\n".toByteArray(Charsets.US_ASCII))
                        flush()
                    }
                    readLineRaw(socket.getInputStream())
                    proofReceived.countDown()
                    // 挂起直到客户端断开
                    while (socket.getInputStream().read() >= 0) Unit
                }
            }
            val receiver = LocalBackupTransfer.Receiver(testDevice(server), "123456")
            val receiveTask = executor.submit<String> { receiver.run() }

            assertTrue(proofReceived.await(2, TimeUnit.SECONDS))
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

    private fun testDevice(server: ServerSocket) =
        LocalBackupTransfer.Device("test", "test", "127.0.0.1", server.localPort)

    private fun ExecutorService.submitSession(
        server: ServerSocket,
        pin: String,
        json: String = "{}",
    ): Future<Boolean> = submit<Boolean> {
        runBlocking {
            LocalBackupTransfer.serveSession(server, pin, json, isStopped = { false }, failureDelayMillis = { 0 })
        }
    }

    /**
     * 启动一个符合 lan-handshake-v1.1 的伪发送服务器：发 CHALLENGE、校验客户端 proof
     * （锁定发送端 proof 格式）、回 [responseLine]（缺省为合法 "OK <size> <mac>"）并写 payload。
     */
    private fun scriptedServer(
        pin: String,
        payload: ByteArray,
        responseLine: String? = null,
    ): ServerSocket {
        val server = ServerSocket(0)
        Executors.newSingleThreadExecutor().submit {
            try {
                server.accept().use { socket ->
                    socket.soTimeout = 5_000
                    val input = socket.getInputStream()
                    val output = socket.getOutputStream()
                    val nonce = ByteArray(16).also(SecureRandom()::nextBytes)
                    output.apply {
                        write("CHALLENGE ${nonce.toHex()}\n".toByteArray(Charsets.US_ASCII))
                        flush()
                    }
                    val proofLine = readLineRaw(input)
                    assertTrue(proofLine.startsWith("FLASH-AERO/1 "))
                    val actualProof = proofLine.substring("FLASH-AERO/1 ".length)
                    val expectedProof = with(LocalBackupTransfer) { computeProof(pin, nonce).toHex() }
                    assertEquals(expectedProof, actualProof)
                    val line = responseLine
                        ?: "OK ${payload.size} ${with(LocalBackupTransfer) { computePayloadMac(pin, payload).toHex() }}"
                    output.apply {
                        write("$line\n".toByteArray(Charsets.US_ASCII))
                        if (line != "ERR PIN") write(payload)
                        flush()
                    }
                }
            } catch (_: Exception) {
                // 客户端提前断开等场景直接忽略，断言在测试主线程完成。
            }
        }
        return server
    }

    /** 发送自定义首行（垃圾/畸形流量），并读取服务端关闭连接前的全部响应。 */
    private fun exchangeRaw(port: Int, firstLine: String): String =
        Socket("127.0.0.1", port).use { socket ->
            socket.soTimeout = 5_000
            val input = socket.getInputStream()
            // 服务端建立连接即发送 CHALLENGE；先消费掉再发畸形数据
            readLineRaw(input)
            socket.getOutputStream().apply {
                write("$firstLine\n".toByteArray(Charsets.UTF_8))
                flush()
            }
            input.readBytes().toString(Charsets.UTF_8)
        }

    /** 完整挑战应答握手：读 CHALLENGE，按 [proofPin] 计算 proof，发送并读取全部响应。 */
    private fun exchangeProof(port: Int, pin: String, proofPin: String): String =
        Socket("127.0.0.1", port).use { socket ->
            socket.soTimeout = 5_000
            val input = socket.getInputStream()
            val challenge = readLineRaw(input)
            assertTrue(challenge.startsWith("CHALLENGE "))
            val nonce = challenge.substring("CHALLENGE ".length).hexToBytes()
            val proof = with(LocalBackupTransfer) { computeProof(proofPin, nonce).toHex() }
            socket.getOutputStream().apply {
                write("FLASH-AERO/1 $proof\n".toByteArray(Charsets.UTF_8))
                flush()
            }
            input.readBytes().toString(Charsets.UTF_8)
        }
}

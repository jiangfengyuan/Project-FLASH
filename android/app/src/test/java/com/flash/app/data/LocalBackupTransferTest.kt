// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import java.net.ServerSocket
import java.net.Socket
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
    @Test
    fun `generated PIN is always four digits`() {
        repeat(200) {
            assertTrue(LocalBackupTransfer.generatePin().matches(Regex("\\d{4}")))
        }
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
    fun `garbage connections do not consume PIN attempts`() {
        val server = ServerSocket(0).apply { soTimeout = 100 }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val session = executor.submitSession(server, pin = "1234")
            // 6 个格式非法的连接（已超 5 次上限）不应消耗任何尝试次数，也不应得到回复
            repeat(6) { assertEquals("", exchange(server.localPort, "garbage $it")) }
            // 协议头合法但 PIN 错误：计数并回复 ERR PIN
            repeat(4) { assertEquals("ERR PIN\n", exchange(server.localPort, "FLASH-AERO/1 9999")) }
            // 若垃圾连接也计数，会话早已因到达 5 次上限而关闭
            assertEquals("OK 2\n{}", exchange(server.localPort, "FLASH-AERO/1 1234"))
            assertTrue(session.get(5, TimeUnit.SECONDS))
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun `session closes after five well-formed wrong PIN attempts`() {
        val server = ServerSocket(0).apply { soTimeout = 100 }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val session = executor.submitSession(server, pin = "1234")
            repeat(5) { assertEquals("ERR PIN\n", exchange(server.localPort, "FLASH-AERO/1 0000")) }
            assertFalse(session.get(5, TimeUnit.SECONDS))
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun `protocol header without PIN does not count as an attempt`() {
        val server = ServerSocket(0).apply { soTimeout = 100 }
        val executor = Executors.newSingleThreadExecutor()
        try {
            val session = executor.submitSession(server, pin = "1234")
            // 仅协议头、缺少 PIN 的请求视为格式非法：不计数、不回复
            repeat(6) { assertEquals("", exchange(server.localPort, "FLASH-AERO/1")) }
            assertEquals("OK 2\n{}", exchange(server.localPort, "FLASH-AERO/1 1234"))
            assertTrue(session.get(5, TimeUnit.SECONDS))
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    private fun ExecutorService.submitSession(
        server: ServerSocket,
        pin: String,
        json: String = "{}",
    ): Future<Boolean> = submit<Boolean> {
        runBlocking {
            LocalBackupTransfer.serveSession(server, pin, json) { false }
        }
    }

    /** 发送一行请求，并读取服务端关闭连接前的全部响应。 */
    private fun exchange(port: Int, line: String): String =
        Socket("127.0.0.1", port).use { socket ->
            socket.soTimeout = 5_000
            socket.getOutputStream().apply {
                write("$line\n".toByteArray(Charsets.UTF_8))
                flush()
            }
            socket.getInputStream().readBytes().toString(Charsets.UTF_8)
        }

    @Test
    fun `receiver stop closes an in-flight connection`() {
        val server = ServerSocket(0)
        val accepted = CountDownLatch(1)
        val executor = Executors.newFixedThreadPool(2)
        try {
            val serverTask = executor.submit {
                server.accept().use { socket ->
                    val input = socket.getInputStream()
                    var value: Int
                    do {
                        value = input.read()
                    } while (value >= 0 && value != '\n'.code)
                    check(value == '\n'.code)
                    accepted.countDown()
                    while (input.read() >= 0) Unit
                }
            }
            val receiver = LocalBackupTransfer.Receiver(
                LocalBackupTransfer.Device("test", "test", "127.0.0.1", server.localPort),
                "1234",
            )
            val receiveTask = executor.submit<String> { receiver.run() }

            assertTrue(accepted.await(2, TimeUnit.SECONDS))
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
}

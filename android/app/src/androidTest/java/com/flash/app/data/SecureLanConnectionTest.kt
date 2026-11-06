// Copyright (c) 2026 Fengyuan Jiang · MPL-2.0
package com.flash.app.data

import androidx.test.ext.junit.runners.AndroidJUnit4
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SecureLanConnectionTest {
    @Test fun realJniSocketRequiresBothConfirmationsAndStrictReceipt() = runBlocking {
        withTimeout(15_000) {
            val json = """{"version":"flash-backup-v2","exportedAt":"2026-11-01T00:00:00.000Z","appVersion":"test","notes":"","schemas":{"logs":2,"emotions":2,"tasks":2},"data":{"logs":[],"emotions":[],"tasks":[]}}"""
            val server = ServerSocket(0)
            val calls = AtomicInteger()
            val senderCode = CompletableDeferred<List<Int>>()
            val receiverCode = CompletableDeferred<List<Int>>()
            val senderChannel = CompletableDeferred<SecureLanConnection>()
            val channelOwner = AtomicReference<SecureLanConnection>()
            val client = Socket("127.0.0.1", server.localPort)
            val receiver = SecureLanConnection(client)
            val sender = async(Dispatchers.IO) {
                val channel = SecureLanConnection(server.accept()); channelOwner.set(channel); senderChannel.complete(channel)
                channel.run(true, 120_000, snapshot = { calls.incrementAndGet(); json }) { state, code ->
                    if (state == 6) senderCode.complete(code)
                }
            }
            val received = async(Dispatchers.IO) {
                receiver.run(false, 120_000, snapshot = { error("Receiver must never export") }) { state, code ->
                    if (state == 6) receiverCode.complete(code)
                }
            }
            try {
                assertEquals(senderCode.await(), receiverCode.await())
                assertEquals(0, calls.get())
                senderChannel.await().confirm(); delay(300)
                assertEquals(0, calls.get())
                receiver.confirm()
                assertEquals(json, received.await()); assertNull(sender.await())
                assertEquals(1, calls.get())
            } finally {
                receiver.cancel(); channelOwner.get()?.cancel(); server.close()
                sender.cancel(); received.cancel()
            }
        }
    }
}

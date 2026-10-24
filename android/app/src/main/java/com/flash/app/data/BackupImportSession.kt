package com.flash.app.data

import kotlinx.coroutines.Job
import kotlinx.coroutines.CancellationException
import java.io.Closeable

/** Owns one pending import operation and suppresses callbacks from cancelled
 * generations. It never persists authorization or any backup/session secret. */
internal class BackupImportSession {
    private var generation = 0L
    private var job: Job? = null
    private var resource: Closeable? = null

    @Synchronized fun begin(): Long {
        cancel()
        return generation
    }

    @Synchronized fun attach(expected: Long, operation: Job) {
        if (expected == generation) job = operation else operation.cancel()
    }

    @Synchronized fun publish(expected: Long, action: () -> Unit) {
        if (expected == generation) action()
    }

    @Synchronized fun attachResource(expected: Long, input: Closeable) {
        if (expected != generation) {
            runCatching { input.close() }
            throw CancellationException("导入已取消")
        }
        resource = input
    }

    @Synchronized fun releaseResource(expected: Long, input: Closeable) {
        if (expected == generation && resource === input) resource = null
    }

    @Synchronized fun cancel() {
        generation++
        job?.cancel()
        job = null
        runCatching { resource?.close() }
        resource = null
    }
}

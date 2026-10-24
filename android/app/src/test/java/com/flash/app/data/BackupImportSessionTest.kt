package com.flash.app.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class BackupImportSessionTest {
    @Test fun cancellationClosesOwnedInputAndLateInputIsClosedImmediately() {
        val session = BackupImportSession()
        val generation = session.begin()
        var closes = 0
        val input = java.io.Closeable { closes++ }
        session.attachResource(generation, input)
        session.cancel()
        assertEquals(1, closes)
        assertThrows(kotlinx.coroutines.CancellationException::class.java) {
            session.attachResource(generation, java.io.Closeable { closes++ })
        }
        assertEquals(2, closes)
    }
    @Test fun cancellationPreventsAQueuedWriteAfterSuspension() = runBlocking {
        val session = BackupImportSession()
        val generation = session.begin()
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        var writes = 0
        val operation = launch { entered.complete(Unit); release.await(); writes++ }
        session.attach(generation, operation)
        entered.await()
        session.cancel()
        release.complete(Unit)
        operation.join()
        assertTrue(operation.isCancelled)
        assertEquals(0, writes)
    }

    @Test fun lateAttachmentAndResultCannotReviveACancelledImport() {
        val session = BackupImportSession()
        val old = session.begin()
        session.cancel()
        val late = Job()
        session.attach(old, late)
        var published = false
        session.publish(old) { published = true }
        assertTrue(late.isCancelled)
        assertFalse(published)
    }

    @Test fun newPreviewSupersedesOldOperationAndOnlyPublishesItsOwnResult() {
        val session = BackupImportSession()
        val old = session.begin()
        val oldJob = Job()
        session.attach(old, oldJob)
        val current = session.begin()
        var value = "unchanged"
        session.publish(old) { value = "stale" }
        session.publish(current) { value = "current" }
        assertTrue(oldJob.isCancelled)
        assertEquals("current", value)
    }
}

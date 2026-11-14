package com.flash.app.data

import com.flash.app.data.model.Category
import com.flash.app.ui.capture.CaptureSession
import org.junit.Assert.*
import org.junit.Test

class CaptureSessionTest {
    @Test fun lockedAndSharedSessionsNeverReadPrivateDrafts() {
        val forbidden = { error("private draft must not be accessed") }
        val locked = CaptureSession.create(true, Category.IDEA, null, forbidden)
        assertEquals("", locked.initialText)
        assertFalse(locked.usesPrivateDraft)
        val shared = CaptureSession.create(false, Category.IDEA, "shared", forbidden)
        assertEquals("shared", shared.initialText)
        assertFalse(shared.usesPrivateDraft)
    }
    @Test fun lockingReplacesPrivateStateAndUnlockingDoesNotPromoteRestrictedSession() {
        val owner = CaptureSession.create(false, Category.LOG, null) { "private draft" }
        assertTrue(owner.usesPrivateDraft)
        assertEquals("private draft", owner.initialText)
        val locked = owner.whenLocked(true)
        assertNotEquals(owner.id, locked.id)
        assertEquals("", locked.initialText)
        assertFalse(locked.usesPrivateDraft)
        assertSame(locked, locked.whenLocked(false))
    }
    @Test fun staleLockedAndSharedCallbacksCannotWriteOrClearPrivateDrafts() {
        val owner = CaptureSession.create(false, Category.IDEA, null) { "owner draft" }
        val locked = owner.whenLocked(true)
        val shared = CaptureSession.create(false, Category.IDEA, "shared") { error("private read") }
        assertTrue(owner.canWriteDraft(owner.id, false))
        assertFalse(owner.canWriteDraft(owner.id, true))
        assertFalse(owner.canWriteDraft(locked.id, false))
        assertFalse(owner.canWriteDraft(null, false))
        assertFalse(locked.canWriteDraft(locked.id, false))
        assertFalse(shared.canWriteDraft(shared.id, false))
        var privateDraft = "keep this"
        for (session in listOf(owner, locked, shared)) {
            if (session.canWriteDraft(locked.id, true)) privateDraft = ""
        }
        assertEquals("keep this", privateDraft)
    }
    @Test fun independentSessionsCannotReuseRememberedPrivateText() {
        val owner = CaptureSession.create(false, Category.IDEA, null) { "private" }
        val visitor = CaptureSession.create(true, Category.IDEA, null) { error("private read") }
        assertNotEquals(owner.id, visitor.id)
        val shared = CaptureSession.create(false, Category.LOG, "shared") { error("private read") }
        assertSame(shared, shared.whenLocked(true))
    }
}

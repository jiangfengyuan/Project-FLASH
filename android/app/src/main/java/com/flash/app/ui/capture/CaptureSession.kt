package com.flash.app.ui.capture

import com.flash.app.data.model.Category
import java.util.UUID

/** Draft access is fixed when the session starts; unlocking never promotes a visitor session. */
class CaptureSession private constructor(
    val id: String,
    val category: Category,
    val initialText: String,
    val usesPrivateDraft: Boolean,
) {
    fun canWriteDraft(activeSessionId: String?, locked: Boolean): Boolean =
        usesPrivateDraft && !locked && activeSessionId == id

    fun whenLocked(locked: Boolean): CaptureSession =
        if (locked && usesPrivateDraft) create(true, category, null) { error("locked draft access") } else this

    companion object {
        fun create(locked: Boolean, category: Category, sharedText: String?, privateDraft: () -> String): CaptureSession {
            val owner = !locked && sharedText == null
            return CaptureSession(UUID.randomUUID().toString(), category,
                sharedText ?: if (owner) privateDraft() else "", owner)
        }
    }
}

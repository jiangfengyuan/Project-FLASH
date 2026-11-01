package com.flash.app.data

import android.content.Context
import androidx.room.Room
import androidx.test.platform.app.InstrumentationRegistry
import com.flash.app.data.db.FlashDatabase
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test

/** Explicit two-invocation probe: invoke phase=write, stop app, then phase=read.
 * The normal suite skips it; it must never touch the production database. */
class Schema2ProcessProbeTest {
    @Test fun actualPeerExportSurvivesProcessBoundary() = runBlocking {
        val phase = InstrumentationRegistry.getArguments().getString("schema2ProbePhase")
        assumeTrue("Run the documented isolated write/read phases", phase == "write" || phase == "read")
        val input = InstrumentationRegistry.getArguments().getString("schema2ProbeInput") ?: "apple"
        require(input == "apple" || input == "harmony")
        val dbName = "$DB-$input"
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val json = instrumentation.context.assets.open("actual-exports/$input-schema2.json")
            .bufferedReader().use { it.readText() }
        val incoming = Backup.parseStrict(json)
        if (phase == "write") context.deleteDatabase(dbName)
        assertTrue(phase == "write" || context.getDatabasePath(dbName).exists())
        val database = Room.databaseBuilder(context, FlashDatabase::class.java, dbName).build()
        try {
            val repo = FlashRepository(database)
            val idea = incoming.logs.first { it.category == com.flash.app.data.model.Category.IDEA }.id
            if (phase == "write") {
                repo.replaceAll(incoming.logs, incoming.emotions, incoming.tasks)
                repo.markIdeaViewed(idea)
            }
            val actual = repo.exportSnapshot()
            assertEquals(incoming.logs.sortedBy { it.id }, actual.logs.sortedBy { it.id })
            assertEquals(incoming.emotions.sortedBy { it.id }, actual.emotions.sortedBy { it.id })
            assertEquals(incoming.tasks.sortedBy { it.id }, actual.tasks.sortedBy { it.id })
            assertTrue(repo.isIdeaViewed(idea))
            if (phase == "read") {
                val exported = Backup.exportJson(actual.logs, actual.emotions, actual.tasks,
                    "Fictional cross-process compatibility evidence")
                context.openFileOutput("hardening-schema2-$input-android-export.json", Context.MODE_PRIVATE).use {
                    it.write(exported.toByteArray(Charsets.UTF_8))
                }
            }
        } finally { database.close() }
    }

    companion object { private const val DB = "hardening-schema2-process-probe" }
}

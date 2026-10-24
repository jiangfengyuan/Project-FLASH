package com.flash.app.data

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import androidx.test.platform.app.InstrumentationRegistry

/** Native Android tzdb/codec probe, distinct from JVM and physical-device runs. */
class TimeZoneCompatibilityTest {
    @Test fun modernAndLegacyZonesUseNativeRulesAndRetainWireNames() {
        val context = InstrumentationRegistry.getInstrumentation().context
        val original = context.assets.open("actual-exports/apple-schema2.json").bufferedReader().use { it.readText() }
        for ((modern, legacy) in listOf("Europe/Kyiv" to "Europe/Kiev", "Asia/Kolkata" to "Asia/Calcutta",
            "Asia/Kathmandu" to "Asia/Katmandu", "Africa/Asmara" to "Africa/Asmera")) {
            for (instant in listOf("1900-01-01T00:00:00Z", "2026-03-29T01:30:00Z", "2026-10-25T01:30:00Z", "2050-07-01T00:00:00Z")) {
                val point = java.time.Instant.parse(instant)
                assertEquals(CanonicalTimeZones.zoneId(legacy)!!.rules.getOffset(point),
                    CanonicalTimeZones.zoneId(modern)!!.rules.getOffset(point))
            }
            for (zone in listOf(modern, legacy)) {
                val document = JSONObject(original)
                val due = document.getJSONObject("data").getJSONArray("tasks").getJSONObject(0).getJSONObject("due")
                due.remove("date"); due.put("kind", "dateTime"); due.put("at", "2026-10-25T22:30:00Z"); due.put("timeZone", zone)
                val first = Backup.parseStrict(document.toString())
                val second = Backup.parseStrict(Backup.exportJson(first.logs, first.emotions, first.tasks))
                assertEquals(first.tasks.sortedBy { it.id }, second.tasks.sortedBy { it.id })
                assertEquals(zone, second.tasks.first { it.id == first.tasks[0].id }.timeZone)
            }
        }
    }
}

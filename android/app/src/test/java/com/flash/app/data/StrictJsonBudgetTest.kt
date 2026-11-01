package com.flash.app.data

import org.junit.Assert.assertThrows
import org.junit.Test

class StrictJsonBudgetTest {
    @Test fun denseInputIsRejectedByRawScannerBeforeOrgJsonAllocation() {
        // About20MiB, below the byte cap, but over the common10M value budget.
        // Invoke the scanner directly so the parent regression cannot allocate
        // millions of org.json objects before demonstrating the missing guard.
        val input = "[" + "0,".repeat(10_000_000) + "0]"
        assertThrows(Backup.BackupFormatException::class.java) { StrictJson(input).validate() }
    }
}

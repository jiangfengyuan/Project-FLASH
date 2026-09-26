// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.components

import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.Instant

/** DatePicker represents calendar days at UTC midnight, independent of device zone. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordDateField(value: String, onChange: (String) -> Unit, enabled: Boolean = true) {
    var open by remember { mutableStateOf(false) }
    TextButton(onClick = { open = true }, enabled = enabled) { Text("记录日期：$value") }
    if (open) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = LocalDate.parse(value).atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli(),
            yearRange = 1..9999,
        )
        DatePickerDialog(
            onDismissRequest = { open = false },
            confirmButton = {
                TextButton(enabled = state.selectedDateMillis != null, onClick = {
                    state.selectedDateMillis?.let {
                        onChange(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate().toString())
                    }
                    open = false
                }) { Text("确定") }
            },
            dismissButton = { TextButton(onClick = { open = false }) { Text("取消") } },
        ) { DatePicker(state = state) }
    }
}

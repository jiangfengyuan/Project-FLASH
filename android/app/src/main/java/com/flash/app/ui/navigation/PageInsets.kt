// Copyright (c) 2026 Fengyuan Jiang
// SPDX-License-Identifier: MPL-2.0

package com.flash.app.ui.navigation

import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.dp

/** Scrollable content can pass beneath the floating Dock; its last item clears it. */
val LocalPageBottomPadding = staticCompositionLocalOf { 0.dp }

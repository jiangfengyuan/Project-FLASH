package com.flash.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.flash.app.data.ThemeMode
import com.flash.app.ui.navigation.FlashApp
import com.flash.app.ui.theme.FlashTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            FlashRoot()
        }
    }
}

@Composable
private fun FlashRoot() {
    val app = androidx.compose.ui.platform.LocalContext.current.applicationContext as FlashApplication
    val themeMode by app.settings.themeMode.collectAsStateWithLifecycle()
    val uiStyle by app.settings.uiStyle.collectAsStateWithLifecycle()

    val systemDark = isSystemInDarkTheme()
    val darkTheme = when (themeMode) {
        ThemeMode.SYSTEM -> systemDark
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }

    FlashTheme(darkTheme = darkTheme, uiStyle = uiStyle) {
        FlashApp(darkTheme = darkTheme, uiStyle = uiStyle)
    }
}

package com.suseoaa.ilovework

import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import androidx.compose.ui.unit.dp
import com.suseoaa.ilovework.domain.ConfigRepository
import com.suseoaa.ilovework.domain.createSettings
import com.suseoaa.ilovework.mvi.SettingsViewModel
import com.suseoaa.ilovework.ui.AppTheme
import com.suseoaa.ilovework.ui.SettingsScreen

fun main() = application {
    val repository = ConfigRepository(createSettings())
    val viewModel = SettingsViewModel(repository)

    Window(
        onCloseRequest = ::exitApplication,
        title = "ILoveWork — 打工人配置",
        state = rememberWindowState(width = 480.dp, height = 700.dp)
    ) {
        AppTheme {
            SettingsScreen(viewModel = viewModel)
        }
    }
}
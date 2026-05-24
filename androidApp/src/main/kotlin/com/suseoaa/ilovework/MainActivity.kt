package com.suseoaa.ilovework

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.glance.appwidget.GlanceAppWidgetManager
import com.suseoaa.ilovework.domain.ConfigRepository
import com.suseoaa.ilovework.domain.createSettings
import com.suseoaa.ilovework.mvi.SettingsViewModel
import com.suseoaa.ilovework.ui.AppTheme
import com.suseoaa.ilovework.ui.SettingsScreen
import com.suseoaa.ilovework.widget.SalaryWidgetReceiver
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    @OptIn(DelicateCoroutinesApi::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        val repository = ConfigRepository(createSettings())
        val viewModel = SettingsViewModel(repository)

        setContent {
            AppTheme {
                SettingsScreen(
                    viewModel = viewModel,
                    onAddWidgetClick = {
                        GlobalScope.launch {
                            GlanceAppWidgetManager(this@MainActivity).requestPinGlanceAppWidget(
                                receiver = SalaryWidgetReceiver::class.java
                            )
                        }
                    }
                )
            }
        }
    }
}
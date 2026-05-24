package com.suseoaa.ilovework.widget

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.*
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.text.FontWeight
import androidx.glance.unit.ColorProvider
import androidx.glance.appwidget.cornerRadius
import com.suseoaa.ilovework.domain.ConfigRepository
import com.suseoaa.ilovework.domain.SalaryCalculator
import com.suseoaa.ilovework.domain.createSettings
import kotlinx.datetime.Clock
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime

class SalaryWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val repository = ConfigRepository(createSettings())
        
        provideContent {
            val config = repository.getWorkConfig()
            val now = Clock.System.now().toLocalDateTime(TimeZone.currentSystemDefault())
            val state = SalaryCalculator.calculate(now, config)
            
            val backgroundColor = ColorProvider(Color(0xFFFAF9F6))
            val textColor = ColorProvider(Color.Black)
            
            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .background(backgroundColor)
                    .cornerRadius(16.dp)
                    .padding(16.dp)
            ) {
                Column(
                    modifier = GlanceModifier.fillMaxSize(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = if (state.isWorking) "工作中..." else "休息中",
                        style = TextStyle(color = textColor, fontWeight = FontWeight.Bold)
                    )
                    Spacer(modifier = GlanceModifier.height(8.dp))
                    Text(
                        text = "今日已赚:",
                        style = TextStyle(color = textColor)
                    )
                    Text(
                        text = "¥ %.2f".format(state.earnedSalary),
                        style = TextStyle(color = textColor, fontWeight = FontWeight.Bold)
                    )
                }
            }
        }
    }
}

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

import androidx.glance.state.GlanceStateDefinition
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.currentState
import androidx.datastore.preferences.core.Preferences
import java.util.Calendar

class SalaryWidget : GlanceAppWidget() {
    override val stateDefinition: GlanceStateDefinition<*> = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val repository = ConfigRepository(createSettings())
        
        provideContent {
            val prefs = currentState<Preferences>()
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
                    val statusText = when (state.dayType) {
                        com.suseoaa.ilovework.domain.DayType.WORKDAY -> if (state.isWorking) "摸鱼中" else "下班啦"
                        com.suseoaa.ilovework.domain.DayType.REST_PAID -> "休息中 (带薪)"
                        com.suseoaa.ilovework.domain.DayType.REST_UNPAID -> "休息中 (无薪)"
                    }
                    Text(
                        text = statusText,
                        style = TextStyle(color = textColor, fontWeight = FontWeight.Bold)
                    )
                    Spacer(modifier = GlanceModifier.height(8.dp))
                    Text(
                        text = "今日已赚:",
                        style = TextStyle(color = textColor)
                    )
                    Text(
                        text = "¥ %.4f".format(state.earnedSalary),
                        style = TextStyle(color = textColor, fontWeight = FontWeight.Bold)
                    )
                    
                    Spacer(modifier = GlanceModifier.height(4.dp))
                    Text(
                        text = "时薪: ¥ %.2f".format(state.hourlyWage),
                        style = TextStyle(color = ColorProvider(Color.Gray))
                    )
                    
                    if (state.secondsUntilOffWork > 0) {
                        val h = state.secondsUntilOffWork / 3600
                        val m = (state.secondsUntilOffWork % 3600) / 60
                        Text(
                            text = "距离下班: %d小时%d分".format(h, m),
                            style = TextStyle(color = ColorProvider(Color.Gray))
                        )
                    } else if (state.dayType == com.suseoaa.ilovework.domain.DayType.WORKDAY) {
                        Text(
                            text = "打卡下班啦！",
                            style = TextStyle(color = ColorProvider(Color.Gray))
                        )
                    }
                    
                    Spacer(modifier = GlanceModifier.height(8.dp))
                    val daysUntil = getDaysUntilPayday(config.payday)
                    Text(
                        text = if (daysUntil == 0) "💰 今天发工资！" else "距发薪: ${daysUntil}天",
                        style = TextStyle(color = ColorProvider(Color(0xFF2196F3)), fontWeight = FontWeight.Bold)
                    )
                }
            }
        }
    }
    
    private fun getDaysUntilPayday(payday: Int): Int {
        val cal = Calendar.getInstance()
        val today = Calendar.getInstance()
        
        val currentDay = cal.get(Calendar.DAY_OF_MONTH)
        if (currentDay > payday) {
            cal.add(Calendar.MONTH, 1)
        }
        
        val maxDay = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
        cal.set(Calendar.DAY_OF_MONTH, minOf(payday, maxDay))
        
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        
        today.set(Calendar.HOUR_OF_DAY, 0)
        today.set(Calendar.MINUTE, 0)
        today.set(Calendar.SECOND, 0)
        today.set(Calendar.MILLISECOND, 0)
        
        val diffMillis = cal.timeInMillis - today.timeInMillis
        return (diffMillis / (1000 * 60 * 60 * 24)).toInt()
    }
}

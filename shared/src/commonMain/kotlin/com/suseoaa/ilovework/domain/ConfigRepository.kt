package com.suseoaa.ilovework.domain

import com.russhwolf.settings.Settings

class ConfigRepository(private val settings: Settings) {
    
    fun getWorkConfig(): WorkConfig {
        return WorkConfig(
            monthlySalary = settings.getDouble("monthlySalary", 10000.0),
            workMode = WorkMode.valueOf(settings.getString("workMode", WorkMode.DOUBLE_OFF.name)),
            workStartHour = settings.getInt("workStartHour", 9),
            workStartMinute = settings.getInt("workStartMinute", 0),
            workEndHour = settings.getInt("workEndHour", 18),
            workEndMinute = settings.getInt("workEndMinute", 0),
            lunchStartHour = settings.getInt("lunchStartHour", 12),
            lunchStartMinute = settings.getInt("lunchStartMinute", 0),
            lunchEndHour = settings.getInt("lunchEndHour", 13),
            lunchEndMinute = settings.getInt("lunchEndMinute", 30)
        )
    }

    fun saveWorkConfig(config: WorkConfig) {
        settings.putDouble("monthlySalary", config.monthlySalary)
        settings.putString("workMode", config.workMode.name)
        settings.putInt("workStartHour", config.workStartHour)
        settings.putInt("workStartMinute", config.workStartMinute)
        settings.putInt("workEndHour", config.workEndHour)
        settings.putInt("workEndMinute", config.workEndMinute)
        settings.putInt("lunchStartHour", config.lunchStartHour)
        settings.putInt("lunchStartMinute", config.lunchStartMinute)
        settings.putInt("lunchEndHour", config.lunchEndHour)
        settings.putInt("lunchEndMinute", config.lunchEndMinute)
    }
}

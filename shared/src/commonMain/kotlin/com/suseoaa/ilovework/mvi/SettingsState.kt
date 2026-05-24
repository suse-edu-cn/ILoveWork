package com.suseoaa.ilovework.mvi

import com.suseoaa.ilovework.domain.WorkConfig
import com.suseoaa.ilovework.domain.WorkMode

data class SettingsState(
    val monthlySalary: Double = 10000.0,
    val workMode: WorkMode = WorkMode.DOUBLE_OFF,
    val workStartHour: Int = 9,
    val workStartMinute: Int = 0,
    val workEndHour: Int = 18,
    val workEndMinute: Int = 0,
    val lunchStartHour: Int = 12,
    val lunchStartMinute: Int = 0,
    val lunchEndHour: Int = 13,
    val lunchEndMinute: Int = 30,
    val customWorkDays: Set<Int> = setOf(1, 2, 3, 4, 5),
    val statutoryHolidays: Set<String> = emptySet(),
    val statutoryMakeupDays: Set<String> = emptySet(),
    val isRestDayPaid: Boolean = false,
    val isSaved: Boolean = false
) {
    fun toWorkConfig(): WorkConfig = WorkConfig(
        monthlySalary = monthlySalary,
        workMode = workMode,
        workStartHour = workStartHour,
        workStartMinute = workStartMinute,
        workEndHour = workEndHour,
        workEndMinute = workEndMinute,
        lunchStartHour = lunchStartHour,
        lunchStartMinute = lunchStartMinute,
        lunchEndHour = lunchEndHour,
        lunchEndMinute = lunchEndMinute,
        customWorkDays = customWorkDays,
        statutoryHolidays = statutoryHolidays,
        statutoryMakeupDays = statutoryMakeupDays,
        isRestDayPaid = isRestDayPaid
    )

    companion object {
        fun fromWorkConfig(config: WorkConfig) = SettingsState(
            monthlySalary = config.monthlySalary,
            workMode = config.workMode,
            workStartHour = config.workStartHour,
            workStartMinute = config.workStartMinute,
            workEndHour = config.workEndHour,
            workEndMinute = config.workEndMinute,
            lunchStartHour = config.lunchStartHour,
            lunchStartMinute = config.lunchStartMinute,
            lunchEndHour = config.lunchEndHour,
            lunchEndMinute = config.lunchEndMinute,
            customWorkDays = config.customWorkDays,
            statutoryHolidays = config.statutoryHolidays,
            statutoryMakeupDays = config.statutoryMakeupDays,
            isRestDayPaid = config.isRestDayPaid
        )
    }
}

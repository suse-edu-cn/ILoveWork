package com.suseoaa.ilovework.domain

import kotlinx.datetime.*
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

object SalaryCalculator {

    fun calculate(
        currentDateTime: LocalDateTime, 
        config: WorkConfig,
        isWorkDayOverride: Boolean? = null // null means calculate dynamically
    ): SalaryState {
        val date = currentDateTime.date
        val time = currentDateTime.time
        
        // 1. Determine if today is a workday
        val isWorkday = isWorkDayOverride ?: isWorkday(date, config.workMode)
        if (!isWorkday) {
            return SalaryState(0.0, 0.0, false)
        }
        
        // 2. Parse times
        val start = LocalTime(config.workStartHour, config.workStartMinute)
        val end = LocalTime(config.workEndHour, config.workEndMinute)
        val lunchStart = LocalTime(config.lunchStartHour, config.lunchStartMinute)
        val lunchEnd = LocalTime(config.lunchEndHour, config.lunchEndMinute)
        
        // 3. Calculate total daily work seconds
        val totalWorkDuration = calculateDuration(start, end, lunchStart, lunchEnd, end)
        val totalWorkSeconds = totalWorkDuration.inWholeSeconds
        
        // 4. Calculate elapsed work seconds
        val elapsedDuration = calculateDuration(start, end, lunchStart, lunchEnd, time)
        val elapsedSeconds = elapsedDuration.inWholeSeconds
        
        // 5. Calculate salary
        val dailySalary = config.monthlySalary / 21.75
        val salaryPerSecond = if (totalWorkSeconds > 0) dailySalary / totalWorkSeconds else 0.0
        val earnedSalary = elapsedSeconds * salaryPerSecond
        
        return SalaryState(
            dailySalary = dailySalary,
            earnedSalary = earnedSalary,
            isWorking = isWorkingTime(time, start, end, lunchStart, lunchEnd)
        )
    }
    
    private fun isWorkday(date: LocalDate, mode: WorkMode): Boolean {
        val dow = date.dayOfWeek
        return when (mode) {
            WorkMode.DOUBLE_OFF -> dow != DayOfWeek.SATURDAY && dow != DayOfWeek.SUNDAY
            WorkMode.SINGLE_OFF -> dow != DayOfWeek.SUNDAY
            WorkMode.BIG_SMALL_WEEK -> {
                val isEvenWeek = (date.toEpochDays() / 7) % 2 == 0
                if (isEvenWeek) {
                    dow != DayOfWeek.SATURDAY && dow != DayOfWeek.SUNDAY
                } else {
                    dow != DayOfWeek.SUNDAY
                }
            }
            WorkMode.CUSTOM -> true
        }
    }
    
    private fun calculateDuration(
        start: LocalTime,
        end: LocalTime,
        lunchStart: LocalTime,
        lunchEnd: LocalTime,
        current: LocalTime
    ): Duration {
        if (current < start) return Duration.ZERO
        
        val actualCurrent = if (current > end) end else current
        
        val totalElapsed = (actualCurrent.toSecondOfDay() - start.toSecondOfDay())
        
        // Subtract lunch time if applicable
        var lunchElapsed = 0
        if (actualCurrent > lunchStart) {
            val actualLunchEnd = if (actualCurrent > lunchEnd) lunchEnd else actualCurrent
            lunchElapsed = actualLunchEnd.toSecondOfDay() - lunchStart.toSecondOfDay()
        }
        
        val validSeconds = totalElapsed - lunchElapsed
        return if (validSeconds > 0) validSeconds.seconds else Duration.ZERO
    }
    
    private fun isWorkingTime(
        current: LocalTime,
        start: LocalTime,
        end: LocalTime,
        lunchStart: LocalTime,
        lunchEnd: LocalTime
    ): Boolean {
        return current in start..end && current !in lunchStart..lunchEnd
    }
}

data class SalaryState(
    val dailySalary: Double,
    val earnedSalary: Double,
    val isWorking: Boolean
)

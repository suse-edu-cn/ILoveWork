package com.suseoaa.ilovework.domain

import kotlinx.datetime.*
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

enum class DayType {
    WORKDAY, REST_PAID, REST_UNPAID
}

object SalaryCalculator {

    fun calculate(
        currentDateTime: LocalDateTime, 
        config: WorkConfig,
        dayTypeOverride: DayType? = null // null means calculate dynamically
    ): SalaryState {
        val date = currentDateTime.date
        val time = currentDateTime.time
        
        // 1. Determine day type
        val dayType = dayTypeOverride ?: getDayType(date, config)
        if (dayType == DayType.REST_UNPAID) {
            return SalaryState(0.0, 0.0, false, dayType, 0.0, 0L)
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
        
        // If it's a paid rest day, they aren't working but they still earn money over time.
        val isWorking = if (dayType == DayType.REST_PAID) false else isWorkingTime(time, start, end, lunchStart, lunchEnd)
        
        val hourlyWage = if (totalWorkSeconds > 0) dailySalary / (totalWorkSeconds / 3600.0) else 0.0
        val secondsUntilOffWork = if (time < end) (end.toSecondOfDay() - time.toSecondOfDay()).toLong() else 0L
        
        return SalaryState(
            dailySalary = dailySalary,
            earnedSalary = earnedSalary,
            isWorking = isWorking,
            dayType = dayType,
            hourlyWage = hourlyWage,
            secondsUntilOffWork = secondsUntilOffWork
        )
    }
    
    private fun getDayType(date: LocalDate, config: WorkConfig): DayType {
        // "No Rest" mode explicitly works every day, ignoring all holidays
        if (config.workMode == WorkMode.NO_REST) {
            return DayType.WORKDAY
        }
        
        val dateString = date.toString()
        
        // 1. Highest priority: Statutory Makeup Days
        if (config.statutoryMakeupDays.contains(dateString)) {
            return DayType.WORKDAY
        }
        
        // 2. Second highest priority: Statutory Holidays (Paid)
        if (config.statutoryHolidays.contains(dateString)) {
            return DayType.REST_PAID
        }
        
        val dow = date.dayOfWeek
        val isWorkday = when (config.workMode) {
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
            WorkMode.CUSTOM -> config.customWorkDays.contains(dow.isoDayNumber)
            WorkMode.NO_REST -> true
        }
        return if (isWorkday) DayType.WORKDAY else {
            if (config.isRestDayPaid) DayType.REST_PAID else DayType.REST_UNPAID
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
    val isWorking: Boolean,
    val dayType: DayType,
    val hourlyWage: Double = 0.0,
    val secondsUntilOffWork: Long = 0L
)

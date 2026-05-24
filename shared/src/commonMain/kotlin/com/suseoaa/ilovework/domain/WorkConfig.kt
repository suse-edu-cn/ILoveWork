package com.suseoaa.ilovework.domain

enum class WorkMode {
    DOUBLE_OFF, // 双休
    SINGLE_OFF, // 单休
    BIG_SMALL_WEEK, // 大小周
    CUSTOM, // 调休或自定义
    NO_REST // 不休
}

data class WorkConfig(
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
    val customWorkDays: Set<Int> = setOf(1, 2, 3, 4, 5), // 1=Mon, 7=Sun
    val statutoryHolidays: Set<String> = emptySet(), // Format: YYYY-MM-DD
    val statutoryMakeupDays: Set<String> = emptySet(), // Format: YYYY-MM-DD
    val isRestDayPaid: Boolean = false, // Whether regular rest days are paid
    val payday: Int = 10
)

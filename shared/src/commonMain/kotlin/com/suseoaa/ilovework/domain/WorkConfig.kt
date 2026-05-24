package com.suseoaa.ilovework.domain

enum class WorkMode {
    DOUBLE_OFF, // 双休
    SINGLE_OFF, // 单休
    BIG_SMALL_WEEK, // 大小周
    CUSTOM // 调休或自定义
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
    val lunchEndMinute: Int = 30
)

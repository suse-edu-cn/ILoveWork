package com.suseoaa.ilovework.mvi

import com.suseoaa.ilovework.domain.WorkMode

sealed class SettingsIntent {
    data class UpdateSalary(val salary: Double) : SettingsIntent()
    data class UpdateWorkMode(val mode: WorkMode) : SettingsIntent()
    data class UpdateWorkStart(val hour: Int, val minute: Int) : SettingsIntent()
    data class UpdateWorkEnd(val hour: Int, val minute: Int) : SettingsIntent()
    data class UpdateLunchStart(val hour: Int, val minute: Int) : SettingsIntent()
    data class UpdateLunchEnd(val hour: Int, val minute: Int) : SettingsIntent()
    object SaveConfig : SettingsIntent()
}

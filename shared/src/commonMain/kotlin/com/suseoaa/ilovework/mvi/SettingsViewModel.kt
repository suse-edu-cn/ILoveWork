package com.suseoaa.ilovework.mvi

import com.suseoaa.ilovework.domain.ConfigRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * MVI ViewModel — pure Kotlin, no Android/Compose dependency.
 * Android and macOS platforms consume this via StateFlow.
 */
class SettingsViewModel(private val repository: ConfigRepository) {

    private val _state = MutableStateFlow(SettingsState.fromWorkConfig(repository.getWorkConfig()))
    val state: StateFlow<SettingsState> = _state.asStateFlow()

    private fun calculateEnd(
        startH: Int, startM: Int,
        lStartH: Int, lStartM: Int,
        lEndH: Int, lEndM: Int,
        workHours: Double
    ): Pair<Int, Int> {
        val startMins = startH * 60 + startM
        val lunchMins = (lEndH * 60 + lEndM) - (lStartH * 60 + lStartM)
        val workMins = (workHours * 60).toInt()
        val actualLunch = if (lunchMins > 0) lunchMins else 0
        val totalMins = startMins + actualLunch + workMins
        return Pair((totalMins / 60) % 24, totalMins % 60)
    }

    fun dispatch(intent: SettingsIntent) {
        when (intent) {
            is SettingsIntent.UpdateSalary ->
                _state.update { it.copy(monthlySalary = intent.salary, isSaved = false) }

            is SettingsIntent.UpdateWorkMode ->
                _state.update { it.copy(workMode = intent.mode, isSaved = false) }

            is SettingsIntent.UpdateWorkStart ->
                _state.update { 
                    val (endH, endM) = calculateEnd(intent.hour, intent.minute, it.lunchStartHour, it.lunchStartMinute, it.lunchEndHour, it.lunchEndMinute, it.workHoursPerDay)
                    it.copy(workStartHour = intent.hour, workStartMinute = intent.minute, workEndHour = endH, workEndMinute = endM, isSaved = false) 
                }

            is SettingsIntent.UpdateWorkEnd ->
                _state.update { it.copy(workEndHour = intent.hour, workEndMinute = intent.minute, isSaved = false) }

            is SettingsIntent.UpdateLunchStart ->
                _state.update { 
                    val (endH, endM) = calculateEnd(it.workStartHour, it.workStartMinute, intent.hour, intent.minute, it.lunchEndHour, it.lunchEndMinute, it.workHoursPerDay)
                    it.copy(lunchStartHour = intent.hour, lunchStartMinute = intent.minute, workEndHour = endH, workEndMinute = endM, isSaved = false) 
                }

            is SettingsIntent.UpdateLunchEnd ->
                _state.update { 
                    val (endH, endM) = calculateEnd(it.workStartHour, it.workStartMinute, it.lunchStartHour, it.lunchStartMinute, intent.hour, intent.minute, it.workHoursPerDay)
                    it.copy(lunchEndHour = intent.hour, lunchEndMinute = intent.minute, workEndHour = endH, workEndMinute = endM, isSaved = false) 
                }

            is SettingsIntent.UpdateCustomWorkDays ->
                _state.update { it.copy(customWorkDays = intent.days, isSaved = false) }

            is SettingsIntent.UpdateStatutoryHolidays ->
                _state.update { it.copy(statutoryHolidays = intent.holidays, statutoryMakeupDays = intent.makeupDays, isSaved = false) }

            is SettingsIntent.UpdateIsRestDayPaid ->
                _state.update { it.copy(isRestDayPaid = intent.isPaid, isSaved = false) }

            is SettingsIntent.UpdatePayday ->
                _state.update { it.copy(payday = intent.day, isSaved = false) }
                
            is SettingsIntent.UpdateWorkHoursPerDay ->
                _state.update { 
                    val (endH, endM) = calculateEnd(it.workStartHour, it.workStartMinute, it.lunchStartHour, it.lunchStartMinute, it.lunchEndHour, it.lunchEndMinute, intent.hours)
                    it.copy(workHoursPerDay = intent.hours, workEndHour = endH, workEndMinute = endM, isSaved = false)
                }



            is SettingsIntent.SaveConfig -> {
                val config = _state.value.toWorkConfig()
                repository.saveWorkConfig(config)
                _state.update { it.copy(isSaved = true) }
            }
        }
    }
}

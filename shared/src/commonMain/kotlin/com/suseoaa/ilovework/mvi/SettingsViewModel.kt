package com.suseoaa.ilovework.mvi

import com.suseoaa.ilovework.domain.ConfigRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * MVI ViewModel — pure Kotlin, no Android/Compose dependency.
 * Both Android and Desktop platforms consume this via StateFlow.
 */
class SettingsViewModel(private val repository: ConfigRepository) {

    private val _state = MutableStateFlow(SettingsState.fromWorkConfig(repository.getWorkConfig()))
    val state: StateFlow<SettingsState> = _state.asStateFlow()

    fun dispatch(intent: SettingsIntent) {
        when (intent) {
            is SettingsIntent.UpdateSalary ->
                _state.update { it.copy(monthlySalary = intent.salary, isSaved = false) }

            is SettingsIntent.UpdateWorkMode ->
                _state.update { it.copy(workMode = intent.mode, isSaved = false) }

            is SettingsIntent.UpdateWorkStart ->
                _state.update { it.copy(workStartHour = intent.hour, workStartMinute = intent.minute, isSaved = false) }

            is SettingsIntent.UpdateWorkEnd ->
                _state.update { it.copy(workEndHour = intent.hour, workEndMinute = intent.minute, isSaved = false) }

            is SettingsIntent.UpdateLunchStart ->
                _state.update { it.copy(lunchStartHour = intent.hour, lunchStartMinute = intent.minute, isSaved = false) }

            is SettingsIntent.UpdateLunchEnd ->
                _state.update { it.copy(lunchEndHour = intent.hour, lunchEndMinute = intent.minute, isSaved = false) }

            is SettingsIntent.UpdateCustomWorkDays ->
                _state.update { it.copy(customWorkDays = intent.days, isSaved = false) }

            is SettingsIntent.UpdateStatutoryHolidays ->
                _state.update { it.copy(statutoryHolidays = intent.holidays, statutoryMakeupDays = intent.makeupDays, isSaved = false) }

            is SettingsIntent.UpdateIsRestDayPaid ->
                _state.update { it.copy(isRestDayPaid = intent.isPaid, isSaved = false) }

            is SettingsIntent.SaveConfig -> {
                val config = _state.value.toWorkConfig()
                repository.saveWorkConfig(config)
                _state.update { it.copy(isSaved = true) }
            }
        }
    }
}

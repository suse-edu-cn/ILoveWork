package com.suseoaa.ilovework.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.dp
import com.suseoaa.ilovework.domain.WorkMode
import com.suseoaa.ilovework.mvi.SettingsIntent
import com.suseoaa.ilovework.mvi.SettingsState
import com.suseoaa.ilovework.mvi.SettingsViewModel
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import com.suseoaa.ilovework.widget.SalaryWidget
import androidx.glance.appwidget.updateAll
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.compose.ui.graphics.Color
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.datastore.preferences.core.longPreferencesKey

@Composable
fun SettingsScreen(viewModel: SettingsViewModel, onAddWidgetClick: () -> Unit = {}) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var syncStatus by remember { mutableStateOf("") }
    
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted: Boolean ->
        if (isGranted) {
            syncStatus = "正在查询系统节假日日历..."
            coroutineScope.launch {
                val (holidays, makeupDays) = withContext(Dispatchers.IO) {
                    CalendarHelper.syncHolidays(context)
                }
                viewModel.dispatch(SettingsIntent.UpdateStatutoryHolidays(holidays, makeupDays))
                viewModel.dispatch(SettingsIntent.SaveConfig)
                SalaryWidget().updateAll(context)
                syncStatus = "✓ 成功获取 ${holidays.size} 天休息日，${makeupDays.size} 天调休上班"
            }
        } else {
            syncStatus = "❌ 同步失败：未获得日历权限"
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "打工人配置",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground
        )

        // Salary
        CardItem {
            Text("月薪设置", style = MaterialTheme.typography.titleMedium)
            
            var salaryStr by remember { 
                mutableStateOf(if (state.monthlySalary == state.monthlySalary.toLong().toDouble())
                    state.monthlySalary.toLong().toString()
                else state.monthlySalary.toString()) 
            }
            
            LaunchedEffect(state.monthlySalary) {
                val currentParsed = salaryStr.toDoubleOrNull()
                if (currentParsed != state.monthlySalary) {
                    salaryStr = if (state.monthlySalary == state.monthlySalary.toLong().toDouble())
                        state.monthlySalary.toLong().toString()
                    else state.monthlySalary.toString()
                }
            }

            OutlinedTextField(
                value = salaryStr,
                onValueChange = { v ->
                    salaryStr = v
                    v.toDoubleOrNull()?.let { viewModel.dispatch(SettingsIntent.UpdateSalary(it)) }
                },
                label = { Text("月薪（元）") },
                modifier = Modifier.fillMaxWidth()
            )
        }

        // Payday
        CardItem {
            Text("发薪日设置", style = MaterialTheme.typography.titleMedium)
            
            var paydayStr by remember { mutableStateOf(state.payday.toString()) }
            
            LaunchedEffect(state.payday) {
                if (paydayStr.toIntOrNull() != state.payday) {
                    paydayStr = state.payday.toString()
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("每月发薪日：")
                OutlinedTextField(
                    value = paydayStr,
                    onValueChange = { v ->
                        val filtered = v.filter { it.isDigit() }
                        paydayStr = filtered
                        val p = filtered.toIntOrNull()
                        if (p != null && p in 1..31) {
                            viewModel.dispatch(SettingsIntent.UpdatePayday(p))
                        }
                    },
                    label = { Text("号") },
                    modifier = Modifier.width(100.dp)
                )
            }
        }

        // Work Mode
        CardItem {
            Text("工作模式", style = MaterialTheme.typography.titleMedium)
            WorkMode.values().forEach { mode ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(
                        selected = state.workMode == mode,
                        onClick = { viewModel.dispatch(SettingsIntent.UpdateWorkMode(mode)) }
                    )
                    Text(
                        text = when (mode) {
                            WorkMode.DOUBLE_OFF -> "双休"
                            WorkMode.SINGLE_OFF -> "单休"
                            WorkMode.BIG_SMALL_WEEK -> "大小周"
                            WorkMode.CUSTOM -> "调休或自定义"
                            WorkMode.NO_REST -> "不休"
                        }
                    )
                }
            }
            
            Text(
                text = when (state.workMode) {
                    WorkMode.DOUBLE_OFF -> "每周工作 5 天，周末双休。"
                    WorkMode.SINGLE_OFF -> "每周工作 6 天，周日单休。"
                    WorkMode.BIG_SMALL_WEEK -> "大小周交替，单周休一天，双周休两天。"
                    WorkMode.CUSTOM -> "自定义每周工作日，请勾选下方需要上班的日子。"
                    WorkMode.NO_REST -> "牛马模式：每周工作 7 天，全无休假。"
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.secondary
            )
            
            if (state.workMode == WorkMode.CUSTOM) {
                Spacer(modifier = Modifier.height(4.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    val days = listOf(1 to "一", 2 to "二", 3 to "三", 4 to "四", 5 to "五", 6 to "六", 7 to "日")
                    days.forEach { (num, name) ->
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Checkbox(
                                checked = state.customWorkDays.contains(num),
                                onCheckedChange = { isChecked ->
                                    val newDays = state.customWorkDays.toMutableSet()
                                    if (isChecked) newDays.add(num) else newDays.remove(num)
                                    viewModel.dispatch(SettingsIntent.UpdateCustomWorkDays(newDays))
                                }
                            )
                            Text(name, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                Checkbox(
                    checked = state.isRestDayPaid,
                    onCheckedChange = { viewModel.dispatch(SettingsIntent.UpdateIsRestDayPaid(it)) }
                )
                Text("休息日是否带薪 (开启后，周末等休息日也会计算工资)", style = MaterialTheme.typography.bodyMedium)
            }
        }
        
        // Statutory Holidays Sync
        CardItem {
            Text("法定节假日同步", style = MaterialTheme.typography.titleMedium)
            Text(
                "系统日历包含了法定节假日及调休安排。如果您希望在节假日和小组件上自动精准计算，请点击同步。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.secondary
            )
            
            Row(verticalAlignment = Alignment.CenterVertically) {
                Button(onClick = {
                    if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED) {
                        syncStatus = "正在查询系统节假日日历..."
                        coroutineScope.launch {
                            val (holidays, makeupDays) = withContext(Dispatchers.IO) {
                                CalendarHelper.syncHolidays(context)
                            }
                            viewModel.dispatch(SettingsIntent.UpdateStatutoryHolidays(holidays, makeupDays))
                            viewModel.dispatch(SettingsIntent.SaveConfig)
                            
                            val manager = GlanceAppWidgetManager(context)
                            val glanceIds = manager.getGlanceIds(SalaryWidget::class.java)
                            glanceIds.forEach { glanceId ->
                                updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
                                    prefs.toMutablePreferences().apply {
                                        this[longPreferencesKey("last_update")] = System.currentTimeMillis()
                                    }
                                }
                            }
                            SalaryWidget().updateAll(context)
                            syncStatus = "✓ 成功获取 ${holidays.size} 天休息日，${makeupDays.size} 天调休上班"
                        }
                    } else {
                        launcher.launch(Manifest.permission.READ_CALENDAR)
                    }
                }) {
                    Text("同步系统节假日")
                }
            }
            
            if (syncStatus.isNotEmpty()) {
                Text(syncStatus, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
            }
            
            if (state.statutoryHolidays.isNotEmpty()) {
                Text(
                    "当前已同步 ${state.statutoryHolidays.size} 个休息日，${state.statutoryMakeupDays.size} 个调休上班日",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF4CAF50)
                )
            }
        }

        // Work Hours
        CardItem {
            Text("上班时间", style = MaterialTheme.typography.titleMedium)
            TimePickerRow("上班", state.workStartHour, state.workStartMinute) { h, m ->
                viewModel.dispatch(SettingsIntent.UpdateWorkStart(h, m))
            }
            TimePickerRow("下班", state.workEndHour, state.workEndMinute) { h, m ->
                viewModel.dispatch(SettingsIntent.UpdateWorkEnd(h, m))
            }
        }

        // Lunch Hours
        CardItem {
            Text("午休时间", style = MaterialTheme.typography.titleMedium)
            TimePickerRow("开始", state.lunchStartHour, state.lunchStartMinute) { h, m ->
                viewModel.dispatch(SettingsIntent.UpdateLunchStart(h, m))
            }
            TimePickerRow("结束", state.lunchEndHour, state.lunchEndMinute) { h, m ->
                viewModel.dispatch(SettingsIntent.UpdateLunchEnd(h, m))
            }
        }

        Button(
            onClick = { 
                viewModel.dispatch(SettingsIntent.SaveConfig) 
                coroutineScope.launch {
                    val manager = GlanceAppWidgetManager(context)
                    val glanceIds = manager.getGlanceIds(SalaryWidget::class.java)
                    glanceIds.forEach { glanceId ->
                        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
                            prefs.toMutablePreferences().apply {
                                this[longPreferencesKey("last_update")] = System.currentTimeMillis()
                            }
                        }
                    }
                    SalaryWidget().updateAll(context)
                    com.suseoaa.ilovework.widget.WidgetUpdateScheduler.startPeriodicRefresh(context)
                    com.suseoaa.ilovework.reminder.ReminderScheduler.scheduleReminders(context)
                }
            },
            modifier = Modifier.fillMaxWidth().height(52.dp)
        ) {
            Text(if (state.isSaved) "✓ 已保存" else "保存配置")
        }

        OutlinedButton(
            onClick = onAddWidgetClick,
            modifier = Modifier.fillMaxWidth().height(52.dp)
        ) {
            Text("一键将小组件添加到桌面")
        }
    }
}

@Composable
private fun CardItem(content: @Composable ColumnScope.() -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().shadow(6.dp, RoundedCornerShape(16.dp)),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            content = content
        )
    }
}

@Composable
private fun TimePickerRow(label: String, hour: Int, minute: Int, onChanged: (Int, Int) -> Unit) {
    var hourStr by remember { mutableStateOf(hour.toString().padStart(2, '0')) }
    var minuteStr by remember { mutableStateOf(minute.toString().padStart(2, '0')) }

    LaunchedEffect(hour) {
        if (hourStr.toIntOrNull() != hour) {
            hourStr = hour.toString().padStart(2, '0')
        }
    }
    LaunchedEffect(minute) {
        if (minuteStr.toIntOrNull() != minute) {
            minuteStr = minute.toString().padStart(2, '0')
        }
    }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(label, modifier = Modifier.width(40.dp))
        OutlinedTextField(
            value = hourStr,
            onValueChange = { v -> 
                val filtered = v.filter { it.isDigit() }
                hourStr = filtered
                filtered.toIntOrNull()?.let { h -> 
                    if (h in 0..23) onChanged(h, minute)
                }
            },
            label = { Text("时") },
            modifier = Modifier.weight(1f)
        )
        Text(":")
        OutlinedTextField(
            value = minuteStr,
            onValueChange = { v -> 
                val filtered = v.filter { it.isDigit() }
                minuteStr = filtered
                filtered.toIntOrNull()?.let { m -> 
                    if (m in 0..59) onChanged(hour, m)
                }
            },
            label = { Text("分") },
            modifier = Modifier.weight(1f)
        )
    }
}

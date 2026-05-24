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

@Composable
fun SettingsScreen(viewModel: SettingsViewModel, onAddWidgetClick: () -> Unit = {}) {
    val state by viewModel.state.collectAsState()

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
            OutlinedTextField(
                value = if (state.monthlySalary == state.monthlySalary.toLong().toDouble())
                    state.monthlySalary.toLong().toString()
                else state.monthlySalary.toString(),
                onValueChange = { v ->
                    v.toDoubleOrNull()?.let { viewModel.dispatch(SettingsIntent.UpdateSalary(it)) }
                },
                label = { Text("月薪（元）") },
                modifier = Modifier.fillMaxWidth()
            )
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
                        }
                    )
                }
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
            onClick = { viewModel.dispatch(SettingsIntent.SaveConfig) },
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
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(label, modifier = Modifier.width(40.dp))
        OutlinedTextField(
            value = hour.toString().padStart(2, '0'),
            onValueChange = { onChanged(it.toIntOrNull() ?: hour, minute) },
            label = { Text("时") },
            modifier = Modifier.weight(1f)
        )
        Text(":")
        OutlinedTextField(
            value = minute.toString().padStart(2, '0'),
            onValueChange = { onChanged(hour, it.toIntOrNull() ?: minute) },
            label = { Text("分") },
            modifier = Modifier.weight(1f)
        )
    }
}

import SwiftUI

struct WorkModeSettingsView: View {
    @Bindable var vm: ConfigViewModel

    private let allDays = [
        (1, "一"), (2, "二"), (3, "三"), (4, "四"), (5, "五"), (6, "六"), (7, "日")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox(label: Label("工作模式", systemImage: "calendar")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("", selection: $vm.workMode) {
                            ForEach(WorkMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(modeDescription(vm.workMode))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if vm.workMode == .custom {
                            HStack(spacing: 12) {
                                ForEach(allDays, id: \.0) { day in
                                    Toggle(isOn: Binding(
                                        get: { vm.customWorkDays.contains(day.0) },
                                        set: { isOn in
                                            if isOn { vm.customWorkDays.insert(day.0) }
                                            else { vm.customWorkDays.remove(day.0) }
                                        }
                                    )) {
                                        Text(day.1)
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                            .padding(.top, 4)
                        }

                        Divider()

                        Toggle(isOn: $vm.isRestDayPaid) {
                            Text("休息日是否带薪 (开启后，周末等休息日也会计算工资)")
                        }
                        .toggleStyle(.checkbox)
                    }
                    .padding(.top, 6)
                }

                GroupBox(label: Label("法定节假日同步", systemImage: "arrow.triangle.2.circlepath")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("系统日历包含了中国大陆的法定节假日及调休安排。如果您希望在节假日和小组件上自动精准计算，请点击同步。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button(action: { vm.syncHolidays() }) {
                                Text("同步系统节假日")
                            }

                            if !vm.syncStatus.isEmpty {
                                Text(vm.syncStatus)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }

                        if !vm.statutoryHolidays.isEmpty {
                            Text("当前已同步 \(vm.statutoryHolidays.count) 个休息日，\(vm.statutoryMakeupDays.count) 个调休上班日")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(24)
        }
    }

    private func modeDescription(_ mode: WorkMode) -> String {
        switch mode {
        case .doubleOff: return "每周工作 5 天，周末双休。"
        case .singleOff: return "每周工作 6 天，周日单休。"
        case .bigSmallWeek: return "大小周交替，单周休一天，双周休两天。"
        case .custom: return "自定义每周工作日，请勾选下方需要上班的日子。"
        case .noRest: return "牛马模式：每周工作 7 天，全无休假。"
        }
    }
}

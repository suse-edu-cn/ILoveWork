import SwiftUI

struct WorkTimeSettingsView: View {
    @Bindable var vm: ConfigViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox(label: Label("上班时间", systemImage: "clock")) {
                    VStack(spacing: 10) {
                        HStack {
                            Text("每日工作时长(包含午休)")
                                .frame(width: 140, alignment: .leading)

                            Stepper(value: $vm.workHoursPerDay, in: 4...24, step: 0.5) {
                                Text(String(format: "%.1f 小时", vm.workHoursPerDay))
                            }
                            Spacer()
                        }

                        Divider()

                        TimeRow(label: "上班",
                                hour: $vm.workStartHour,
                                minute: $vm.workStartMinute)
                        Divider()
                        TimeRow(label: "下班",
                                hour: $vm.workEndHour,
                                minute: $vm.workEndMinute)
                    }
                    .padding(.top, 6)
                }

                GroupBox(label: Label("午休时间", systemImage: "fork.knife")) {
                    VStack(spacing: 10) {
                        TimeRow(label: "开始",
                                hour: $vm.lunchStartHour,
                                minute: $vm.lunchStartMinute)
                        Divider()
                        TimeRow(label: "结束",
                                hour: $vm.lunchEndHour,
                                minute: $vm.lunchEndMinute)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Time Picker Row

struct TimeRow: View {
    let label: String
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 36, alignment: .leading)
                .foregroundStyle(.secondary)
            Spacer()

            HStack(spacing: 2) {
                TextField("", value: $hour, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 36)
                    .textFieldStyle(.roundedBorder)
                Stepper("", value: $hour, in: 0...23)
                    .labelsHidden()
            }

            Text(":")

            HStack(spacing: 2) {
                TextField("", value: $minute, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 36)
                    .textFieldStyle(.roundedBorder)
                Stepper("", value: $minute, in: 0...59, step: 5)
                    .labelsHidden()
            }
        }
    }
}

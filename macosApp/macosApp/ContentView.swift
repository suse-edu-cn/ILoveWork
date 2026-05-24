import SwiftUI
import WidgetKit

// MARK: - Observable Config ViewModel

@Observable
class ConfigViewModel {
    var monthlySalary: Double
    var workMode: WorkMode
    var workStartHour: Int
    var workStartMinute: Int
    var workEndHour: Int
    var workEndMinute: Int
    var lunchStartHour: Int
    var lunchStartMinute: Int
    var lunchEndHour: Int
    var lunchEndMinute: Int
    var saveStatus: String = ""

    init() {
        let cfg = ConfigStore.load()
        monthlySalary   = cfg.monthlySalary
        workMode        = cfg.workMode
        workStartHour   = cfg.workStartHour
        workStartMinute = cfg.workStartMinute
        workEndHour     = cfg.workEndHour
        workEndMinute   = cfg.workEndMinute
        lunchStartHour  = cfg.lunchStartHour
        lunchStartMinute = cfg.lunchStartMinute
        lunchEndHour    = cfg.lunchEndHour
        lunchEndMinute  = cfg.lunchEndMinute
    }

    func save() {
        let cfg = WorkConfig(
            monthlySalary:   monthlySalary,
            workMode:        workMode,
            workStartHour:   workStartHour,
            workStartMinute: workStartMinute,
            workEndHour:     workEndHour,
            workEndMinute:   workEndMinute,
            lunchStartHour:  lunchStartHour,
            lunchStartMinute: lunchStartMinute,
            lunchEndHour:    lunchEndHour,
            lunchEndMinute:  lunchEndMinute
        )
        ConfigStore.save(cfg)
        WidgetCenter.shared.reloadAllTimelines()
        saveStatus = "✓ 已保存，小组件正在刷新…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.saveStatus = ""
        }
    }
}

// MARK: - Main Settings View

struct ContentView: View {
    @State private var vm = ConfigViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                HStack {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("打工人配置")
                            .font(.title2.bold())
                        Text("配置你的薪资与工作时间，小组件实时显示今日收入")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)

                Divider()

                // Salary
                GroupBox(label: Label("月薪设置", systemImage: "yensign.circle")) {
                    HStack {
                        Text("月薪")
                        Spacer()
                        TextField("月薪", value: $vm.monthlySalary, format: .number)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 130)
                        Text("元/月")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                // Work Mode
                GroupBox(label: Label("工作模式", systemImage: "calendar")) {
                    Picker("", selection: $vm.workMode) {
                        ForEach(WorkMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 6)
                }

                // Work Hours
                GroupBox(label: Label("上班时间", systemImage: "clock")) {
                    VStack(spacing: 10) {
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

                // Lunch Hours
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

                // Save
                VStack(spacing: 8) {
                    Button(action: vm.save) {
                        Text("保存配置并刷新小组件")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if !vm.saveStatus.isEmpty {
                        Text(vm.saveStatus)
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut, value: vm.saveStatus)
            }
            .padding(24)
        }
        .frame(minWidth: 420, minHeight: 500)
        .background(.windowBackground)
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
            Stepper(value: $hour, in: 0...23) {
                Text(String(format: "%02d 时", hour))
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
            Text(":")
            Stepper(value: $minute, in: 0...59, step: 5) {
                Text(String(format: "%02d 分", minute))
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
        }
    }
}

#Preview {
    ContentView()
}

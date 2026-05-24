import SwiftUI
import WidgetKit
import EventKit

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
    var customWorkDays: Set<Int>
    var statutoryHolidays: Set<String>
    var statutoryMakeupDays: Set<String>
    var isRestDayPaid: Bool
    var payday: Int
    
    var saveStatus: String = ""
    var syncStatus: String = ""

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
        customWorkDays  = cfg.customWorkDays
        statutoryHolidays = cfg.statutoryHolidays
        statutoryMakeupDays = cfg.statutoryMakeupDays
        isRestDayPaid   = cfg.isRestDayPaid
        payday          = cfg.payday
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
            lunchEndMinute:  lunchEndMinute,
            customWorkDays:  customWorkDays,
            statutoryHolidays: statutoryHolidays,
            statutoryMakeupDays: statutoryMakeupDays,
            isRestDayPaid:   isRestDayPaid,
            payday:          payday
        )
        ConfigStore.save(cfg)
        WidgetCenter.shared.reloadAllTimelines()
        NotificationManager.shared.scheduleReminders(config: cfg)
        saveStatus = "✓ 已保存，小组件正在刷新…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.saveStatus = ""
        }
    }
    
    func syncHolidays() {
        syncStatus = "正在请求权限..."
        let store = EKEventStore()
        
        let completion: EKEventStoreRequestAccessCompletionHandler = { [weak self] (granted, error) in
            guard granted, error == nil else {
                DispatchQueue.main.async { self?.syncStatus = "❌ 同步失败：未获得日历权限" }
                return
            }
            
            DispatchQueue.main.async { self?.syncStatus = "正在查询系统节假日日历..." }
            let calendars = store.calendars(for: .event)
            let holidayCalendar = calendars.first { $0.title.contains("节假日") || $0.title.contains("Holiday") }
            
            guard let calendar = holidayCalendar else {
                DispatchQueue.main.async { self?.syncStatus = "❌ 找不到系统节假日日历，请确保已在系统日历中订阅" }
                return
            }
            
            // Search from start of this year to end of next year
            let now = Date()
            let currentYear = Calendar.current.component(.year, from: now)
            let startDate = Calendar.current.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
            let endDate = Calendar.current.date(from: DateComponents(year: currentYear + 1, month: 12, day: 31))!
            
            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
            let events = store.events(matching: predicate)
            
            var holidays = Set<String>()
            var makeupDays = Set<String>()
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            
            for event in events {
                if event.title.contains("休") {
                    holidays.insert(df.string(from: event.startDate))
                } else if event.title.contains("班") {
                    makeupDays.insert(df.string(from: event.startDate))
                }
            }
            
            DispatchQueue.main.async {
                self?.statutoryHolidays = holidays
                self?.statutoryMakeupDays = makeupDays
                self?.syncStatus = "✓ 成功获取 \(holidays.count) 天休息日，\(makeupDays.count) 天调休上班"
                // Auto-save after syncing
                self?.save()
            }
        }
        
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents(completion: completion)
        } else {
            store.requestAccess(to: .event, completion: completion)
        }
    }
}

// MARK: - Main Settings View

struct ContentView: View {
    @State private var vm = ConfigViewModel()
    @State private var notificationPermissionStatus: String = "检查中..."
    @State private var pendingNotifications: [String] = []

    let allDays = [
        (1, "一"), (2, "二"), (3, "三"), (4, "四"), (5, "五"), (6, "六"), (7, "日")
    ]

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

                // Payday
                GroupBox(label: Label("发薪日设置", systemImage: "calendar.badge.clock")) {
                    HStack {
                        Text("每月发薪日")
                        Spacer()
                        Stepper("", value: $vm.payday, in: 1...31)
                            .labelsHidden()
                        TextField("", value: $vm.payday, format: .number)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 40)
                        Text("号")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                // Work Mode
                GroupBox(label: Label("工作模式", systemImage: "calendar")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("", selection: $vm.workMode) {
                            ForEach(WorkMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        // Description of current mode
                        Text(modeDescription(vm.workMode))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Custom days picker
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
                
                // Statutory Holidays Sync
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

                // Notification Debug Panel
                GroupBox(label: Label("下班提醒状态", systemImage: "bell.badge")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("通知权限：")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notificationPermissionStatus)
                                .font(.caption.bold())
                                .foregroundStyle(notificationPermissionStatus.contains("已授权") ? .green : .red)
                        }

                        if !pendingNotifications.isEmpty {
                            Text("已计划的提醒：")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(pendingNotifications, id: \.self) { n in
                                Text("• " + n)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        } else {
                            Text("暂无已计划的提醒（请先保存配置）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Button("刷新状态") {
                                refreshNotificationStatus()
                            }
                            Button("测试通知（5秒后）") {
                                NotificationManager.shared.sendTestNotification()
                            }
                        }
                        .controlSize(.small)
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
        .frame(minWidth: 420, minHeight: 650)
        .background(.windowBackground)
        .onAppear {
            refreshNotificationStatus()
        }
    }
    
    private func refreshNotificationStatus() {
        NotificationManager.shared.checkPermissionStatus { status in
            switch status {
            case .authorized:    notificationPermissionStatus = "✅ 已授权"
            case .denied:        notificationPermissionStatus = "❌ 已拒绝（请到系统设置 > 通知 > 我爱上班 里开启）"
            case .notDetermined: notificationPermissionStatus = "⚠️ 未决定"
            case .provisional:   notificationPermissionStatus = "⚠️ 临时授权"
            @unknown default:    notificationPermissionStatus = "❓ 未知"
            }
        }
        NotificationManager.shared.listPendingNotifications { notifications in
            pendingNotifications = notifications
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

#Preview {
    ContentView()
}

import SwiftUI
import WidgetKit
import EventKit
import Foundation
import AppKit

// MARK: - Observable Config ViewModel

@Observable
class ConfigViewModel {
    var monthlySalary: Double
    var workMode: WorkMode
    var workStartHour: Int { didSet { recalculateEndTime() } }
    var workStartMinute: Int { didSet { recalculateEndTime() } }
    var workEndHour: Int
    var workEndMinute: Int
    var lunchStartHour: Int { didSet { recalculateEndTime() } }
    var lunchStartMinute: Int { didSet { recalculateEndTime() } }
    var lunchEndHour: Int { didSet { recalculateEndTime() } }
    var lunchEndMinute: Int { didSet { recalculateEndTime() } }
    var customWorkDays: Set<Int>
    var statutoryHolidays: Set<String>
    var statutoryMakeupDays: Set<String>
    var isRestDayPaid: Bool
    var payday: Int

    var workHoursPerDay: Double { didSet { recalculateEndTime() } }
    var refreshFrequency: Int

    // Slacking mode
    var workAppBundleIDs: Set<String>

    var saveStatus: String = ""
    var syncStatus: String = ""

    var liveWorkConfig: WorkConfig {
        WorkConfig(
            monthlySalary: monthlySalary,
            workMode: workMode,
            workStartHour: workStartHour,
            workStartMinute: workStartMinute,
            workEndHour: workEndHour,
            workEndMinute: workEndMinute,
            lunchStartHour: lunchStartHour,
            lunchStartMinute: lunchStartMinute,
            lunchEndHour: lunchEndHour,
            lunchEndMinute: lunchEndMinute,
            customWorkDays: customWorkDays,
            statutoryHolidays: statutoryHolidays,
            statutoryMakeupDays: statutoryMakeupDays,
            isRestDayPaid: isRestDayPaid,
            payday: payday,
            workHoursPerDay: workHoursPerDay,
            refreshFrequency: refreshFrequency,
            workAppBundleIDs: workAppBundleIDs
        )
    }

    private func recalculateEndTime() {
        let startMins = workStartHour * 60 + workStartMinute
        let lunchMins = (lunchEndHour * 60 + lunchEndMinute) - (lunchStartHour * 60 + lunchStartMinute)
        let workMins = Int(workHoursPerDay * 60)
        let actualLunch = lunchMins > 0 ? lunchMins : 0
        let totalMins = startMins + actualLunch + workMins
        workEndHour = (totalMins / 60) % 24
        workEndMinute = totalMins % 60
    }

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
        workHoursPerDay = cfg.workHoursPerDay
        refreshFrequency = cfg.refreshFrequency
        workAppBundleIDs = cfg.workAppBundleIDs
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
            payday:          payday,
            workHoursPerDay: workHoursPerDay,
            refreshFrequency: refreshFrequency,
            workAppBundleIDs: workAppBundleIDs
        )
        ConfigStore.save(cfg)
        NotificationCenter.default.post(name: NSNotification.Name("ConfigSaved"), object: nil)
        NotificationManager.shared.scheduleReminders(config: cfg)
        saveStatus = "✓ 已保存，小组件正在刷新…"

        // Clear widget cache then reload after a short delay to let the filesystem propagate
        ConfigStore.clearWidgetCache()
        SlackingTracker.shared.updateData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WidgetCenter.shared.reloadAllTimelines()
        }
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

// MARK: - Main Content View

struct ContentView: View {
    @State private var vm = ConfigViewModel()
    @State private var selectedSection: SidebarItem? = .basic

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSection)
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            HStack(spacing: 0) {
                // Left: Settings content
                Group {
                    switch selectedSection ?? .basic {
                    case .basic:
                        BasicSettingsView(vm: vm)
                    case .workTime:
                        WorkTimeSettingsView(vm: vm)
                    case .workMode:
                        WorkModeSettingsView(vm: vm)
                    case .slacking:
                        SlackingSettingsView(vm: vm)
                    case .other:
                        OtherSettingsView(vm: vm)
                    case .update:
                        UpdateView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Right: Widget preview (always visible)
                WidgetPreviewPanel(vm: vm)
                    .frame(width: 320)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        if !vm.saveStatus.isEmpty {
                            Text(vm.saveStatus)
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        Button(action: vm.save) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("保存")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 500)
        .background(.windowBackground)
    }
}

// MARK: - Widget Preview Panel (always visible on the right)

private struct WidgetPreviewPanel: View {
    let vm: ConfigViewModel
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let config = vm.liveWorkConfig
        let formula = ConfigStore.buildFormula(from: config, on: now)
        let (earned, isWorking, dayType, hourlyWage, secondsUntil) = formula.earned(at: now)
        let daysUntilPayday = ConfigStore.computeDaysUntilPayday(payday: vm.payday, from: now)
        let slackingData = SlackingStore.load()

        VStack(spacing: 16) {
            Text("小组件预览")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Salary - Medium widget
            MediumPreview(
                earnedAmount: earned,
                isWorking: isWorking,
                dayType: dayType,
                hourlyWage: hourlyWage,
                secondsUntilOff: secondsUntil,
                daysUntilPayday: daysUntilPayday,
                dailySalary: formula.dailySalary
            )
            .aspectRatio(2.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)

            // Salary - Small widget
            SmallPreview(
                earnedAmount: earned,
                isWorking: isWorking,
                dayType: dayType,
                hourlyWage: hourlyWage,
                secondsUntilOff: secondsUntil,
                daysUntilPayday: daysUntilPayday
            )
            .frame(maxWidth: 150)
            .aspectRatio(1.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)

            // Slacking - Medium widget
            SlackingMediumPreview(data: slackingData)
                .aspectRatio(2.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)

            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground.opacity(0.5))
        .onReceive(timer) { time in
            now = time
        }
    }
}

#Preview {
    ContentView()
}

import Foundation
import WidgetKit

// MARK: - Data Model

enum WorkMode: String, CaseIterable {
    case doubleOff = "DOUBLE_OFF"
    case singleOff = "SINGLE_OFF"
    case bigSmallWeek = "BIG_SMALL_WEEK"
    case custom = "CUSTOM"
    case noRest = "NO_REST"

    var displayName: String {
        switch self {
        case .doubleOff:      return "双休"
        case .singleOff:      return "单休"
        case .bigSmallWeek:   return "大小周"
        case .custom:         return "自定义"
        case .noRest:         return "不休"
        }
    }
}

struct WorkConfig {
    var monthlySalary: Double  = 10000.0
    var workMode: WorkMode     = .doubleOff
    var workStartHour: Int     = 9
    var workStartMinute: Int   = 0
    var workEndHour: Int       = 18
    var workEndMinute: Int     = 0
    var lunchStartHour: Int    = 12
    var lunchStartMinute: Int  = 0
    var lunchEndHour: Int      = 13
    var lunchEndMinute: Int    = 30
    
    var customWorkDays: Set<Int> = [1, 2, 3, 4, 5] // 1=Mon, 7=Sun
    var statutoryHolidays: Set<String> = [] // YYYY-MM-DD
    var statutoryMakeupDays: Set<String> = [] // YYYY-MM-DD
    var isRestDayPaid: Bool = false
}

// MARK: - Formatter Helper

private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    return df
}()

enum ConfigStore {
    static var configURL: URL {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        if bundleID == "com.suseoaa.ilovework.macos.SalaryWidget" {
            // 小组件被强制沙盒化，只能读写自己沙盒内的 Documents 目录
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("ilovework_config.txt")
        } else {
            // 主程序（取消沙盒后）具有所有权限，直接跨界写入到小组件的沙盒目录中
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent("Library/Containers/com.suseoaa.ilovework.macos.SalaryWidget/Data/Documents/ilovework_config.txt")
        }
    }

    static func load() -> WorkConfig {
        var cfg = WorkConfig()
        guard let content = try? String(contentsOf: configURL, encoding: .utf8) else {
            return cfg
        }

        var d = [String: String]()
        for line in content.components(separatedBy: .newlines) {
            guard !line.hasPrefix("#"), !line.isEmpty else { continue }
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                d[key] = value
            }
        }

        if let v = d["monthlySalary"].flatMap(Double.init)  { cfg.monthlySalary   = v }
        if let v = d["workMode"].flatMap(WorkMode.init)     { cfg.workMode         = v }
        if let v = d["workStartHour"].flatMap(Int.init)     { cfg.workStartHour    = v }
        if let v = d["workStartMinute"].flatMap(Int.init)   { cfg.workStartMinute  = v }
        if let v = d["workEndHour"].flatMap(Int.init)       { cfg.workEndHour      = v }
        if let v = d["workEndMinute"].flatMap(Int.init)     { cfg.workEndMinute    = v }
        if let v = d["lunchStartHour"].flatMap(Int.init)    { cfg.lunchStartHour   = v }
        if let v = d["lunchStartMinute"].flatMap(Int.init)  { cfg.lunchStartMinute = v }
        if let v = d["lunchEndHour"].flatMap(Int.init)      { cfg.lunchEndHour     = v }
        if let v = d["lunchEndMinute"].flatMap(Int.init)    { cfg.lunchEndMinute   = v }
        
        if let v = d["customWorkDays"] {
            let days = v.split(separator: ",").compactMap { Int($0) }
            if !days.isEmpty { cfg.customWorkDays = Set(days) }
            else if v == "" { cfg.customWorkDays = [] }
        }
        
        if let v = d["statutoryHolidays"] {
            let dates = v.split(separator: ",").map(String.init)
            cfg.statutoryHolidays = Set(dates)
        }
        
        if let v = d["statutoryMakeupDays"] {
            let dates = v.split(separator: ",").map(String.init)
            cfg.statutoryMakeupDays = Set(dates)
        }
        
        if let v = d["isRestDayPaid"].flatMap(Bool.init) { cfg.isRestDayPaid = v }

        return cfg
    }

    static func save(_ cfg: WorkConfig) {
        var lines = [String]()
        lines.append("monthlySalary=\(cfg.monthlySalary)")
        lines.append("workMode=\(cfg.workMode.rawValue)")
        lines.append("workStartHour=\(cfg.workStartHour)")
        lines.append("workStartMinute=\(cfg.workStartMinute)")
        lines.append("workEndHour=\(cfg.workEndHour)")
        lines.append("workEndMinute=\(cfg.workEndMinute)")
        lines.append("lunchStartHour=\(cfg.lunchStartHour)")
        lines.append("lunchStartMinute=\(cfg.lunchStartMinute)")
        lines.append("lunchEndHour=\(cfg.lunchEndHour)")
        lines.append("lunchEndMinute=\(cfg.lunchEndMinute)")
        
        let customDaysStr = cfg.customWorkDays.map(String.init).joined(separator: ",")
        lines.append("customWorkDays=\(customDaysStr)")
        
        let holidaysStr = cfg.statutoryHolidays.joined(separator: ",")
        lines.append("statutoryHolidays=\(holidaysStr)")
        
        let makeupDaysStr = cfg.statutoryMakeupDays.joined(separator: ",")
        lines.append("statutoryMakeupDays=\(makeupDaysStr)")
        lines.append("isRestDayPaid=\(cfg.isRestDayPaid)")
        
        let url = configURL
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        let content = lines.joined(separator: "\n")
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    enum DayType {
        case workday
        case restPaid
        case restUnpaid
    }

    // MARK: - Pre-compute salary formula (called once on save)
    struct SalaryFormula {
        let salaryPerSecond: Double
        let dailySalary: Double
        let workStart: Date
        let workEnd: Date
        let lunchStart: Date
        let lunchEnd: Date
        let dayType: DayType

        func earned(at date: Date) -> (salary: Double, isWorking: Bool, dayType: DayType, hourlyWage: Double, secondsUntilOffWork: TimeInterval) {
            let hourlyWage = salaryPerSecond * 3600.0
            let secondsUntilOffWork = max(0, workEnd.timeIntervalSince(date))
            
            if dayType == .restUnpaid {
                return (0, false, dayType, hourlyWage, secondsUntilOffWork)
            }
            guard date >= workStart else { return (0, false, dayType, hourlyWage, secondsUntilOffWork) }
            
            let cur = min(date, workEnd)
            let totalElapsed = cur.timeIntervalSince(workStart)
            var lunchElapsed: TimeInterval = 0
            if cur > lunchStart {
                lunchElapsed = min(cur, lunchEnd).timeIntervalSince(lunchStart)
            }
            let validElapsed = max(0, totalElapsed - lunchElapsed)
            
            let isWorking: Bool
            if dayType == .restPaid {
                isWorking = false // Rest day, not working
            } else {
                isWorking = date >= workStart && date <= workEnd
                             && !(date >= lunchStart && date <= lunchEnd)
            }
            
            return (validElapsed * salaryPerSecond, isWorking, dayType, hourlyWage, secondsUntilOffWork)
        }
    }

    static func buildFormula(from cfg: WorkConfig, on date: Date = Date()) -> SalaryFormula {
        let cal = Calendar.current
        func t(_ h: Int, _ m: Int) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0, of: date)!
        }
        let ws = t(cfg.workStartHour, cfg.workStartMinute)
        let we = t(cfg.workEndHour, cfg.workEndMinute)
        let ls = t(cfg.lunchStartHour, cfg.lunchStartMinute)
        let le = t(cfg.lunchEndHour, cfg.lunchEndMinute)

        let totalWork = we.timeIntervalSince(ws) - le.timeIntervalSince(ls)
        let dailySalary = cfg.monthlySalary / 21.75
        let sps = totalWork > 0 ? dailySalary / totalWork : 0.0

        let dayType = getDayType(date: date, cfg: cfg)
        return SalaryFormula(salaryPerSecond: sps,
                             dailySalary: dailySalary,
                             workStart: ws, workEnd: we,
                             lunchStart: ls, lunchEnd: le,
                             dayType: dayType)
    }

    private static func getDayType(date: Date, cfg: WorkConfig) -> DayType {
        // "No Rest" mode explicitly works every day, ignoring all holidays
        if cfg.workMode == .noRest {
            return .workday
        }
        
        let dateString = dateFormatter.string(from: date)
        
        // 1. Highest priority: Statutory Makeup Days
        if cfg.statutoryMakeupDays.contains(dateString) {
            return .workday
        }
        
        // 2. Second highest priority: Statutory Holidays (Paid Rest)
        if cfg.statutoryHolidays.contains(dateString) {
            return .restPaid
        }
        
        // 3. Fallback to normal WorkMode logic
        let foundationWeekday = Calendar.current.component(.weekday, from: date)
        let isoWeekday = foundationWeekday == 1 ? 7 : foundationWeekday - 1
        
        let isWorkday: Bool
        switch cfg.workMode {
        case .doubleOff:
            isWorkday = isoWeekday != 6 && isoWeekday != 7
        case .singleOff:
            isWorkday = isoWeekday != 7
        case .bigSmallWeek:
            // Even ISO-week → double rest; odd ISO-week → single rest
            let isoWeek = Calendar.current.component(.weekOfYear, from: date)
            isWorkday = isoWeek % 2 == 0 ? (isoWeekday != 6 && isoWeekday != 7) : (isoWeekday != 7)
        case .custom:
            isWorkday = cfg.customWorkDays.contains(isoWeekday)
        case .noRest:
            isWorkday = true
        }
        return isWorkday ? .workday : (cfg.isRestDayPaid ? .restPaid : .restUnpaid)
    }
}

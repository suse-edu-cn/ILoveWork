import Foundation
import WidgetKit

// MARK: - Data Model

enum WorkMode: String, CaseIterable {
    case doubleOff = "DOUBLE_OFF"
    case singleOff = "SINGLE_OFF"
    case bigSmallWeek = "BIG_SMALL_WEEK"
    case custom = "CUSTOM"

    var displayName: String {
        switch self {
        case .doubleOff:      return "双休"
        case .singleOff:      return "单休"
        case .bigSmallWeek:   return "大小周"
        case .custom:         return "调休/自定义"
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
}

// MARK: - File-based persistence via App Group (shared between App + Widget)

enum ConfigStore {
    static let appGroup = "group.com.suseoaa.ilovework"
    static let fileName = "ilovework_config.properties"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    static func load() -> WorkConfig {
        var cfg = WorkConfig()
        guard let url = fileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return cfg }

        var d = [String: String]()
        for line in content.components(separatedBy: .newlines) {
            guard !line.hasPrefix("#"), !line.isEmpty else { continue }
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { d[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1] }
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

        return cfg
    }

    static func save(_ cfg: WorkConfig) {
        guard let url = fileURL else { return }
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
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Pre-compute salary formula (called once on save)
    struct SalaryFormula {
        let salaryPerSecond: Double
        let workStart: Date
        let workEnd: Date
        let lunchStart: Date
        let lunchEnd: Date
        let isWorkday: Bool

        /// Pure arithmetic — no I/O, safe to call every frame
        func earned(at date: Date) -> (salary: Double, isWorking: Bool) {
            guard isWorkday, date >= workStart else { return (0, false) }
            let cur = min(date, workEnd)
            let totalElapsed = cur.timeIntervalSince(workStart)
            var lunchElapsed: TimeInterval = 0
            if cur > lunchStart {
                lunchElapsed = min(cur, lunchEnd).timeIntervalSince(lunchStart)
            }
            let validElapsed = max(0, totalElapsed - lunchElapsed)
            let isWorking = date >= workStart && date <= workEnd
                         && !(date >= lunchStart && date <= lunchEnd)
            return (validElapsed * salaryPerSecond, isWorking)
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

        let isWorkday = isWorkday(date: date, mode: cfg.workMode)
        return SalaryFormula(salaryPerSecond: sps,
                             workStart: ws, workEnd: we,
                             lunchStart: ls, lunchEnd: le,
                             isWorkday: isWorkday)
    }

    private static func isWorkday(date: Date, mode: WorkMode) -> Bool {
        let dow = Calendar.current.component(.weekday, from: date) // 1=Sun, 7=Sat
        switch mode {
        case .doubleOff:    return dow != 1 && dow != 7
        case .singleOff:    return dow != 1
        case .bigSmallWeek:
            // Even ISO-week → double rest; odd ISO-week → single rest
            let isoWeek = Calendar.current.component(.weekOfYear, from: date)
            return isoWeek % 2 == 0 ? (dow != 1 && dow != 7) : (dow != 1)
        case .custom:       return true
        }
    }
}

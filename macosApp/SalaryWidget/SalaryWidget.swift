import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct SalaryEntry: TimelineEntry {
    let date: Date
    let formula: ConfigStore.SalaryFormula
    // Pre-computed display values (computed at entry creation time, zero I/O at render)
    let earnedAmount: Double
    let isWorking: Bool
    let dayType: ConfigStore.DayType
    let hourlyWage: Double
    let secondsUntilOff: TimeInterval
    let daysUntilPayday: Int
}

// MARK: - Timeline Provider

struct SalaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SalaryEntry {
        makeEntry(date: Date(), formula: ConfigStore.buildFormula(from: WorkConfig()), cfg: WorkConfig())
    }

    func getSnapshot(in context: Context, completion: @escaping (SalaryEntry) -> Void) {
        let cfg = ConfigStore.load()
        completion(makeEntry(date: Date(), formula: ConfigStore.buildFormula(from: cfg), cfg: cfg))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SalaryEntry>) -> Void) {
        let cfg = ConfigStore.load()
        let now = Date()

        // One entry per minute for the next 2 hours.
        // Each entry pre-computes its display values so the view is a pure, stateless renderer.
        // The widget switches entries every minute — this is what drives the real-time update.
        var entries: [SalaryEntry] = []
        for minuteOffset in 0..<120 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now)!
            let formula = ConfigStore.buildFormula(from: cfg, on: entryDate)
            entries.append(makeEntry(date: entryDate, formula: formula, cfg: cfg))
        }

        // .atEnd: WidgetKit calls getTimeline again once all 120 entries are consumed (~2 hours).
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(date: Date, formula: ConfigStore.SalaryFormula, cfg: WorkConfig) -> SalaryEntry {
        let (earned, isWorking, dayType, hourlyWage, secondsUntilOff) = formula.earned(at: date)
        return SalaryEntry(
            date: date,
            formula: formula,
            earnedAmount: earned,
            isWorking: isWorking,
            dayType: dayType,
            hourlyWage: hourlyWage,
            secondsUntilOff: secondsUntilOff,
            daysUntilPayday: computeDaysUntilPayday(payday: cfg.payday, from: date)
        )
    }
    
    private func computeDaysUntilPayday(payday: Int, from date: Date) -> Int {
        let cal = Calendar.current
        let currentDay = cal.component(.day, from: date)
        
        var targetMonth = cal.component(.month, from: date)
        var targetYear = cal.component(.year, from: date)
        
        if currentDay > payday {
            targetMonth += 1
            if targetMonth > 12 {
                targetMonth = 1
                targetYear += 1
            }
        }
        
        var comps = DateComponents(year: targetYear, month: targetMonth, day: payday)
        if !comps.isValidDate(in: cal) {
            let range = cal.range(of: .day, in: .month, for: cal.date(from: DateComponents(year: targetYear, month: targetMonth))!)!
            comps.day = range.count
        }
        let targetDate = cal.date(from: comps)!
        let startOfToday = cal.startOfDay(for: date)
        let startOfTarget = cal.startOfDay(for: targetDate)
        
        return cal.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
    }
}

// MARK: - Widget View

struct SalaryWidgetView: View {
    let entry: SalaryEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.12, blue: 0.12)
            : Color(red: 0.98, green: 0.976, blue: 0.965)
    }
    var textPrimary: Color { colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1) }
    var textSecondary: Color { textPrimary.opacity(0.55) }

    var countdownText: String? {
        guard entry.secondsUntilOff > 0 else { return nil }
        let total = Int(entry.secondsUntilOff)
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0
            ? String(format: "%d:%02d 后下班", h, m)
            : String(format: "%d 分后下班", m)
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: smallView
            default:           mediumView
            }
        }
        .containerBackground(for: .widget) { bgColor }
    }

    // MARK: - Small

    @ViewBuilder
    var smallView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(entry.isWorking ? .green : .orange)
                    .frame(width: 6, height: 6)
                Text(statusLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }

            Text("今日已赚")
                .font(.caption)
                .foregroundStyle(textSecondary)

            (Text("¥").font(.callout.bold())
             + Text(String(format: "%.4f", entry.earnedAmount))
                .font(.system(.title2, design: .rounded).bold())
                .monospacedDigit())
            .foregroundStyle(textPrimary)

            HStack(spacing: 6) {
                Text(String(format: "时薪: ¥%.2f", entry.hourlyWage))
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
                    
                Text(entry.daysUntilPayday == 0 ? "💰 发薪啦" : "距发薪: \(entry.daysUntilPayday)天")
                    .font(.system(size: 10).bold())
                    .foregroundStyle(.blue)
            }

            if let countdown = countdownText {
                Text(countdown)
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
                    .monospacedDigit()
            } else if entry.dayType == .workday {
                Text("打卡下班啦！")
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium

    @ViewBuilder
    var mediumView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.isWorking ? .green : .orange)
                        .frame(width: 9, height: 9)
                    Text(statusLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(textPrimary)
                }

                Text("今日已赚")
                    .font(.caption)
                    .foregroundStyle(textSecondary)

                (Text("¥ ").font(.callout.bold())
                 + Text(String(format: "%.4f", entry.earnedAmount))
                    .font(.system(.title, design: .rounded).bold())
                    .monospacedDigit())
                .foregroundStyle(textPrimary)

                Text(String(format: "时薪: ¥%.2f", entry.hourlyWage))
                    .font(.caption2)
                    .foregroundStyle(textSecondary)

                if let countdown = countdownText {
                    Text("⏱ " + countdown)
                        .font(.caption2)
                        .foregroundStyle(textSecondary)
                        .monospacedDigit()
                } else if entry.dayType == .workday {
                    Text("打卡下班啦！")
                        .font(.caption2)
                        .foregroundStyle(textSecondary)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(textSecondary.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: paydayProgressRatio)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: -2) {
                        Text("\(entry.daysUntilPayday)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(entry.daysUntilPayday == 0 ? .green : textPrimary)
                        Text("天")
                            .font(.system(size: 8))
                            .foregroundStyle(textSecondary)
                    }
                }
                .frame(width: 44, height: 44)
                
                Text("发薪倒计时")
                    .font(.system(size: 9))
                    .foregroundStyle(textSecondary)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusLabel: String {
        switch entry.dayType {
        case .workday:    return entry.isWorking ? "工作中" : "休息中"
        case .restPaid:   return "休息中 (带薪)"
        case .restUnpaid: return "休息中 (无薪)"
        }
    }

    private var progressRatio: Double {
        if entry.dayType != .workday { return 0 }
        if entry.secondsUntilOff <= 0 { return 1.0 }

        guard entry.formula.dailySalary > 0 else { return 0 }
        return min(entry.earnedAmount / entry.formula.dailySalary, 1.0)
    }

    private var paydayProgressRatio: Double {
        if entry.daysUntilPayday == 0 { return 1.0 }
        // 粗略以 30 天作为一整个周期的基数来计算圆环比例
        let ratio = 1.0 - (Double(entry.daysUntilPayday) / 30.0)
        return max(0.0, min(ratio, 1.0))
    }
}

// MARK: - Widget Configuration

@main
struct SalaryWidget: Widget {
    let kind = "SalaryWidgetV2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SalaryProvider()) { entry in
            SalaryWidgetView(entry: entry)
        }
        .configurationDisplayName("打工人薪资")
        .description("实时显示今日赚到的薪资，精确到分")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

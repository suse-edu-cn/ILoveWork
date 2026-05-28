import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct SalaryEntry: TimelineEntry {
    let date: Date
    let earnedAmount: Double
    let isWorking: Bool
    let dayType: String
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
        let dayTypeString: String
        switch dayType {
        case .workday:    dayTypeString = "workday"
        case .restPaid:   dayTypeString = "restPaid"
        case .restUnpaid: dayTypeString = "restUnpaid"
        }
        return SalaryEntry(
            date: date,
            earnedAmount: earned,
            isWorking: isWorking,
            dayType: dayTypeString,
            hourlyWage: hourlyWage,
            secondsUntilOff: secondsUntilOff,
            daysUntilPayday: ConfigStore.computeDaysUntilPayday(payday: cfg.payday, from: date)
        )
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
        let s = total % 60
        return String(format: "还有 %d小时%d分钟%d秒 下班", h, m, s)
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
            } else if entry.dayType == "workday" {
                Text("打卡下班啦！")
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium

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
                    Text(countdown)
                        .font(.caption2)
                        .foregroundStyle(textSecondary)
                        .monospacedDigit()
                } else if entry.dayType == "workday" {
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
        case "workday":    return entry.isWorking ? "工作中" : "休息中"
        case "restPaid":   return "休息中 (带薪)"
        default:           return "休息中 (无薪)"
        }
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

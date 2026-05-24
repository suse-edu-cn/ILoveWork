import WidgetKit
import SwiftUI

// MARK: - Timeline Entry (stores pre-computed formula — no I/O at render time)

struct SalaryEntry: TimelineEntry {
    let date: Date
    let formula: ConfigStore.SalaryFormula
}

// MARK: - Timeline Provider

struct SalaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SalaryEntry {
        SalaryEntry(date: Date(), formula: ConfigStore.buildFormula(from: WorkConfig()))
    }

    func getSnapshot(in context: Context, completion: @escaping (SalaryEntry) -> Void) {
        let cfg = ConfigStore.load()
        completion(SalaryEntry(date: Date(), formula: ConfigStore.buildFormula(from: cfg)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SalaryEntry>) -> Void) {
        let cfg = ConfigStore.load()
        let now = Date()

        // Build one entry per minute for the next hour (config is stable between saves).
        // TimelineView(.animation) handles per-frame rendering within each entry.
        var entries: [SalaryEntry] = []
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now)!
            // Rebuild formula for each future day boundary if needed
            let formula = ConfigStore.buildFormula(from: cfg, on: entryDate)
            entries.append(SalaryEntry(date: entryDate, formula: formula))
        }

        // Reload after 1 hour to pick up any config changes
        let reloadDate = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        completion(Timeline(entries: entries, policy: .after(reloadDate)))
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

    var body: some View {
        // TimelineView(.animation) re-renders every display frame.
        // The closure does ONLY arithmetic — zero I/O, zero allocations.
        TimelineView(.animation) { ctx in
            let (earned, isWorking, dayType, hourlyWage, secondsUntilOff) = entry.formula.earned(at: ctx.date)

            switch family {
            case .systemSmall:
                smallView(earned: earned, isWorking: isWorking, dayType: dayType, hourlyWage: hourlyWage, secondsUntilOff: secondsUntilOff)
            default:
                mediumView(earned: earned, isWorking: isWorking, dayType: dayType, hourlyWage: hourlyWage, secondsUntilOff: secondsUntilOff)
            }
        }
        .containerBackground(for: .widget) { bgColor }
    }

    // MARK: Small

    @ViewBuilder
    func smallView(earned: Double, isWorking: Bool, dayType: ConfigStore.DayType, hourlyWage: Double, secondsUntilOff: TimeInterval) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isWorking ? .green : .orange)
                    .frame(width: 7, height: 7)
                let statusText = statusText(isWorking: isWorking, dayType: dayType)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(textSecondary)
            }

            Text("今日已赚")
                .font(.caption)
                .foregroundStyle(textSecondary)

            Text("¥")
                .font(.callout.bold())
                .foregroundStyle(textPrimary)
            + Text(String(format: "%.4f", earned))
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(textPrimary)
                .monospacedDigit()
                
            Text(String(format: "时薪: ¥%.2f", hourlyWage))
                .font(.caption2)
                .foregroundStyle(textSecondary)
                
            if secondsUntilOff > 0 {
                let h = Int(secondsUntilOff) / 3600
                let m = (Int(secondsUntilOff) % 3600) / 60
                let s = Int(secondsUntilOff) % 60
                Text(String(format: "下班: %02d:%02d:%02d", h, m, s))
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
                    .monospacedDigit()
            } else if dayType == .workday {
                Text("打卡下班啦！")
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Medium

    @ViewBuilder
    func mediumView(earned: Double, isWorking: Bool, dayType: ConfigStore.DayType, hourlyWage: Double, secondsUntilOff: TimeInterval) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isWorking ? .green : .orange)
                        .frame(width: 9, height: 9)
                    let statusText = statusText(isWorking: isWorking, dayType: dayType)
                    Text(statusText)
                        .font(.subheadline.bold())
                        .foregroundStyle(textPrimary)
                }

                Text("今日已赚")
                    .font(.caption)
                    .foregroundStyle(textSecondary)

                (Text("¥ ").font(.callout.bold())
                 + Text(String(format: "%.4f", earned))
                    .font(.system(.title, design: .rounded).bold())
                    .monospacedDigit())
                .foregroundStyle(textPrimary)
                
                HStack {
                    Text(String(format: "时薪: ¥%.2f", hourlyWage))
                        .font(.caption2)
                        .foregroundStyle(textSecondary)
                }
                
                if secondsUntilOff > 0 {
                    let h = Int(secondsUntilOff) / 3600
                    let m = (Int(secondsUntilOff) % 3600) / 60
                    let s = Int(secondsUntilOff) % 60
                    Text(String(format: "距离下班还有 %02d:%02d:%02d", h, m, s))
                        .font(.caption2)
                        .foregroundStyle(textSecondary)
                        .monospacedDigit()
                } else if dayType == .workday {
                    Text("打卡下班啦！")
                        .font(.caption2)
                        .foregroundStyle(textSecondary)
                }
            }

            Spacer()

            // Progress arc
            let progress = progressRatio(earned: earned)
            ZStack {
                Circle()
                    .stroke(textSecondary.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(isWorking ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusText(isWorking: Bool, dayType: ConfigStore.DayType) -> String {
        switch dayType {
        case .workday:
            return isWorking ? "工作中" : "休息中"
        case .restPaid:
            return "休息中 (带薪)"
        case .restUnpaid:
            return "休息中 (无薪)"
        }
    }

    private func progressRatio(earned: Double) -> Double {
        let dailySalary = entry.formula.salaryPerSecond
                        * entry.formula.workEnd.timeIntervalSince(entry.formula.workStart)
        guard dailySalary > 0 else { return 0 }
        return min(earned / dailySalary, 1.0)
    }
}

// MARK: - Widget Configuration

@main
struct SalaryWidget: Widget {
    let kind = "SalaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SalaryProvider()) { entry in
            SalaryWidgetView(entry: entry)
        }
        .configurationDisplayName("打工人薪资")
        .description("实时显示今日赚到的薪资，精确到分")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

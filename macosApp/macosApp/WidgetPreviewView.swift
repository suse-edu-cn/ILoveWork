import SwiftUI

struct WidgetPreviewView: View {
    let vm: ConfigViewModel
    @State private var now = Date()
    @State private var previewFamily: PreviewFamily = .small

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum PreviewFamily: String, CaseIterable {
        case small = "小组件"
        case medium = "中组件"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("组件尺寸", selection: $previewFamily) {
                ForEach(PreviewFamily.allCases, id: \.self) { family in
                    Text(family.rawValue).tag(family)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            let config = vm.liveWorkConfig
            let formula = ConfigStore.buildFormula(from: config, on: now)
            let (earned, isWorking, dayType, hourlyWage, secondsUntil) = formula.earned(at: now)
            let daysUntilPayday = ConfigStore.computeDaysUntilPayday(payday: vm.payday, from: now)

            Group {
                switch previewFamily {
                case .small:
                    SmallPreview(
                        earnedAmount: earned,
                        isWorking: isWorking,
                        dayType: dayType,
                        hourlyWage: hourlyWage,
                        secondsUntilOff: secondsUntil,
                        daysUntilPayday: daysUntilPayday
                    )
                    .frame(width: 160, height: 160)
                case .medium:
                    MediumPreview(
                        earnedAmount: earned,
                        isWorking: isWorking,
                        dayType: dayType,
                        hourlyWage: hourlyWage,
                        secondsUntilOff: secondsUntil,
                        daysUntilPayday: daysUntilPayday,
                        dailySalary: formula.dailySalary
                    )
                    .frame(width: 340, height: 160)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
        .onReceive(timer) { time in
            now = time
        }
    }
}

// MARK: - Small Preview

struct SmallPreview: View {
    let earnedAmount: Double
    let isWorking: Bool
    let dayType: ConfigStore.DayType
    let hourlyWage: Double
    let secondsUntilOff: TimeInterval
    let daysUntilPayday: Int

    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.12, blue: 0.12)
            : Color(red: 0.98, green: 0.976, blue: 0.965)
    }
    var textPrimary: Color { colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1) }
    var textSecondary: Color { textPrimary.opacity(0.55) }

    var countdownText: String? {
        guard secondsUntilOff > 0 else { return nil }
        let total = Int(secondsUntilOff)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "还有 %d小时%d分钟%d秒 下班", h, m, s)
    }

    var statusLabel: String {
        switch dayType {
        case .workday:    return isWorking ? "工作中" : "休息中"
        case .restPaid:   return "休息中 (带薪)"
        case .restUnpaid: return "休息中 (无薪)"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isWorking ? .green : .orange)
                    .frame(width: 6, height: 6)
                Text(statusLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }

            Text("今日已赚")
                .font(.caption)
                .foregroundStyle(textSecondary)

            (Text("¥").font(.callout.bold())
             + Text(String(format: "%.4f", earnedAmount))
                .font(.system(.title2, design: .rounded).bold())
                .monospacedDigit())
            .foregroundStyle(textPrimary)

            HStack(spacing: 4) {
                Text(String(format: "时薪: ¥%.2f", hourlyWage))
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)

                Text(daysUntilPayday == 0 ? "💰 发薪啦" : "距发薪:\(daysUntilPayday)天")
                    .font(.system(size: 10).bold())
                    .foregroundStyle(.blue)
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)

            if let countdown = countdownText {
                Text(countdown)
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
                    .monospacedDigit()
            } else if dayType == .workday {
                Text("打卡下班啦！")
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }
        }
        .padding(16)
        .background(bgColor)
    }
}

// MARK: - Medium Preview

struct MediumPreview: View {
    let earnedAmount: Double
    let isWorking: Bool
    let dayType: ConfigStore.DayType
    let hourlyWage: Double
    let secondsUntilOff: TimeInterval
    let daysUntilPayday: Int
    let dailySalary: Double

    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.12, blue: 0.12)
            : Color(red: 0.98, green: 0.976, blue: 0.965)
    }
    var textPrimary: Color { colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1) }
    var textSecondary: Color { textPrimary.opacity(0.55) }

    var countdownText: String? {
        guard secondsUntilOff > 0 else { return nil }
        let total = Int(secondsUntilOff)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "还有 %d小时%d分钟%d秒 下班", h, m, s)
    }

    var statusLabel: String {
        switch dayType {
        case .workday:    return isWorking ? "工作中" : "休息中"
        case .restPaid:   return "休息中 (带薪)"
        case .restUnpaid: return "休息中 (无薪)"
        }
    }

    var paydayProgressRatio: Double {
        if daysUntilPayday == 0 { return 1.0 }
        let ratio = 1.0 - (Double(daysUntilPayday) / 30.0)
        return max(0.0, min(ratio, 1.0))
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isWorking ? .green : .orange)
                        .frame(width: 9, height: 9)
                    Text(statusLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(textPrimary)
                }

                Text("今日已赚")
                    .font(.caption)
                    .foregroundStyle(textSecondary)

                (Text("¥ ").font(.callout.bold())
                 + Text(String(format: "%.4f", earnedAmount))
                    .font(.system(.title, design: .rounded).bold())
                    .monospacedDigit())
                .foregroundStyle(textPrimary)

                Text(String(format: "时薪: ¥%.2f", hourlyWage))
                    .font(.caption2)
                    .foregroundStyle(textSecondary)

                if let countdown = countdownText {
                    Text(countdown)
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

            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(textSecondary.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: paydayProgressRatio)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: -2) {
                        Text("\(daysUntilPayday)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(daysUntilPayday == 0 ? .green : textPrimary)
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
        .padding(30)
        .background(bgColor)
    }
}

// MARK: - Slacking Medium Preview

struct SlackingMediumPreview: View {
    let data: SlackingData

    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.12, blue: 0.12)
            : Color(red: 0.98, green: 0.976, blue: 0.965)
    }
    var textPrimary: Color { colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1) }
    var textSecondary: Color { textPrimary.opacity(0.55) }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(data.isWorking ? .green : .orange)
                        .frame(width: 9, height: 9)
                    Text(data.isWorking ? "工作中" : "摸鱼中")
                        .font(.subheadline.bold())
                        .foregroundStyle(textPrimary)
                }

                Text(data.currentAppName.isEmpty ? "无" : data.currentAppName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)

                Text("当前应用")
                    .font(.system(size: 9))
                    .foregroundStyle(textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                SlackingStatRow(label: "已工作", value: formatDuration(data.workSecondsToday), color: .green)
                SlackingStatRow(label: "已摸鱼", value: formatDuration(data.slackingSecondsToday), color: .red)
                SlackingStatRow(label: "可摸鱼", value: formatDuration(data.availableSlackingSeconds),
                                color: data.availableSlackingSeconds > 0 ? .green : .red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(30)
        .background(bgColor)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)小时\(m)分钟" }
        return "\(m)分钟"
    }
}

private struct SlackingStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }
}

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct SlackingEntry: TimelineEntry {
    let date: Date
    let currentAppName: String
    let isWorking: Bool
    let workSeconds: Double
    let slackingSeconds: Double
    let availableSlackingSeconds: Double
}

// MARK: - Timeline Provider

struct SlackingProvider: TimelineProvider {
    func placeholder(in context: Context) -> SlackingEntry {
        SlackingEntry(date: Date(), currentAppName: "Safari", isWorking: false,
                      workSeconds: 3600, slackingSeconds: 1800, availableSlackingSeconds: 7200)
    }

    func getSnapshot(in context: Context, completion: @escaping (SlackingEntry) -> Void) {
        let data = SlackingStore.load()
        completion(makeEntry(from: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SlackingEntry>) -> Void) {
        let data = SlackingStore.load()
        var entries: [SlackingEntry] = []
        let now = Date()
        // Generate entries every 30 seconds for the next 2 hours
        for offset in 0..<240 {
            let entryDate = Calendar.current.date(byAdding: .second, value: offset * 30, to: now)!
            entries.append(SlackingEntry(
                date: entryDate,
                currentAppName: data.currentAppName,
                isWorking: data.isWorking,
                workSeconds: data.workSecondsToday,
                slackingSeconds: data.slackingSecondsToday,
                availableSlackingSeconds: data.availableSlackingSeconds
            ))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(from data: SlackingData) -> SlackingEntry {
        SlackingEntry(
            date: Date(),
            currentAppName: data.currentAppName,
            isWorking: data.isWorking,
            workSeconds: data.workSecondsToday,
            slackingSeconds: data.slackingSecondsToday,
            availableSlackingSeconds: data.availableSlackingSeconds
        )
    }
}

// MARK: - Widget View

struct SlackingWidgetView: View {
    let entry: SlackingEntry
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
        VStack(spacing: 6) {
            // Status
            HStack(spacing: 4) {
                Circle()
                    .fill(entry.isWorking ? .green : .orange)
                    .frame(width: 6, height: 6)
                Text(entry.isWorking ? "工作中" : "摸鱼中")
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }

            // Current app
            Text(entry.currentAppName.isEmpty ? "无" : entry.currentAppName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textPrimary)
                .lineLimit(1)

            // Stats
            VStack(spacing: 3) {
                HStack {
                    Text("已工作")
                        .font(.system(size: 9))
                        .foregroundStyle(textSecondary)
                    Spacer()
                    Text(formatDuration(entry.workSeconds))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.green)
                        .monospacedDigit()
                }
                HStack {
                    Text("已摸鱼")
                        .font(.system(size: 9))
                        .foregroundStyle(textSecondary)
                    Spacer()
                    Text(formatDuration(entry.slackingSeconds))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)
                        .monospacedDigit()
                }
                HStack {
                    Text("可摸鱼")
                        .font(.system(size: 9))
                        .foregroundStyle(textSecondary)
                    Spacer()
                    Text(formatDuration(entry.availableSlackingSeconds))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(entry.availableSlackingSeconds > 0 ? .green : .red)
                        .monospacedDigit()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium

    var mediumView: some View {
        HStack(spacing: 16) {
            // Left: status + current app
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.isWorking ? .green : .orange)
                        .frame(width: 9, height: 9)
                    Text(entry.isWorking ? "工作中" : "摸鱼中")
                        .font(.subheadline.bold())
                        .foregroundStyle(textPrimary)
                }

                Text(entry.currentAppName.isEmpty ? "无" : entry.currentAppName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)

                Text("当前应用")
                    .font(.system(size: 9))
                    .foregroundStyle(textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Right: stats
            VStack(alignment: .leading, spacing: 8) {
                StatRow(label: "已工作", value: formatDuration(entry.workSeconds), color: .green)
                StatRow(label: "已摸鱼", value: formatDuration(entry.slackingSeconds), color: .red)
                StatRow(label: "可摸鱼", value: formatDuration(entry.availableSlackingSeconds),
                        color: entry.availableSlackingSeconds > 0 ? .green : .red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h\(m)m" }
        return "\(m)m"
    }
}

// MARK: - Stat Row

private struct StatRow: View {
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

// MARK: - Widget Configuration

@main
struct SlackingWidget: Widget {
    let kind = "SlackingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SlackingProvider()) { entry in
            SlackingWidgetView(entry: entry)
        }
        .configurationDisplayName("摸鱼模式")
        .description("实时追踪工作与摸鱼时间，基于系统屏幕使用时间数据")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

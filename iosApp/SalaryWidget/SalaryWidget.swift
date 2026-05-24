import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // TimelineView handles the real-time update, so we just provide a single entry 
        // that refreshes every hour or so.
        let entry = SimpleEntry(date: Date())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct SalaryWidgetEntryView : View {
    var entry: Provider.Entry
    
    // Read from shared AppGroup
    @AppStorage("monthlySalary", store: UserDefaults(suiteName: "group.com.suseoaa.ilovework")) var monthlySalary: Double = 10000.0
    @AppStorage("workStartHour", store: UserDefaults(suiteName: "group.com.suseoaa.ilovework")) var workStartHour: Int = 9
    @AppStorage("workEndHour", store: UserDefaults(suiteName: "group.com.suseoaa.ilovework")) var workEndHour: Int = 18
    @AppStorage("lunchStartHour", store: UserDefaults(suiteName: "group.com.suseoaa.ilovework")) var lunchStartHour: Int = 12
    @AppStorage("lunchEndHour", store: UserDefaults(suiteName: "group.com.suseoaa.ilovework")) var lunchEndHour: Int = 13

    @Environment(\.colorScheme) var colorScheme

    func earnedSalary(at date: Date) -> Double {
        let calendar = Calendar.current
        
        let start = calendar.date(bySettingHour: workStartHour, minute: 0, second: 0, of: date)!
        let end = calendar.date(bySettingHour: workEndHour, minute: 0, second: 0, of: date)!
        let lunchStart = calendar.date(bySettingHour: lunchStartHour, minute: 0, second: 0, of: date)!
        let lunchEnd = calendar.date(bySettingHour: lunchEndHour, minute: 0, second: 0, of: date)!
        
        if date < start { return 0 }
        let current = min(date, end)
        
        let totalElapsed = current.timeIntervalSince(start)
        
        var lunchElapsed: TimeInterval = 0
        if current > lunchStart {
            let actualLunchEnd = min(current, lunchEnd)
            lunchElapsed = actualLunchEnd.timeIntervalSince(lunchStart)
        }
        
        let validElapsed = max(0, totalElapsed - lunchElapsed)
        
        let totalWork = end.timeIntervalSince(start) - lunchEnd.timeIntervalSince(lunchStart)
        
        let dailySalary = monthlySalary / 21.75
        let salaryPerSecond = dailySalary / totalWork
        
        return validElapsed * salaryPerSecond
    }

    var body: some View {
        let bgColor = colorScheme == .dark ? Color(red: 30/255.0, green: 30/255.0, blue: 30/255.0) : Color(red: 250/255.0, green: 249/255.0, blue: 246/255.0)
        let textColor = colorScheme == .dark ? Color.white : Color.black

        TimelineView(.animation) { context in
            let date = context.date
            let salary = earnedSalary(at: date)
            
            VStack(alignment: .center, spacing: 8) {
                Text("今日已赚")
                    .font(.subheadline)
                    .foregroundColor(textColor.opacity(0.8))
                
                Text(String(format: "¥ %.4f", salary))
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding()
        }
    }
}

@main
struct SalaryWidget: Widget {
    let kind: String = "SalaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SalaryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("打工人薪资小组件")
        .description("实时显示你的今日薪资")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

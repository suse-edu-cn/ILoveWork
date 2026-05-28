import SwiftUI
import WidgetKit

@main
struct macosAppApp: App {
    // Fire dynamically to force the widget to regenerate its timeline
    @State private var widgetRefreshTimer = Timer.publish(every: Double(max(1, ConfigStore.load().refreshFrequency)), on: .main, in: .common).autoconnect()

    var body: some Scene {
        WindowGroup("ILoveWork — 打工人配置") {
            ContentView()
                .onAppear {

                    NotificationManager.shared.requestPermission { granted in
                        if granted {
                            let config = ConfigStore.load()
                            NotificationManager.shared.scheduleReminders(config: config)
                        }
                    }
                    SlackingTracker.shared.startTracking()
                }
                .onReceive(widgetRefreshTimer) { _ in
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ConfigSaved"))) { _ in
                    let freq = Double(max(1, ConfigStore.load().refreshFrequency))
                    widgetRefreshTimer = Timer.publish(every: freq, on: .main, in: .common).autoconnect()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1080, height: 640)
    }
}


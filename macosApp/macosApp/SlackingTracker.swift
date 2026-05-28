import Foundation
import AppKit
import WidgetKit
import SQLite3

class SlackingTracker {
    static let shared = SlackingTracker()

    private var timer: Timer?
    private var currentAppBundleID: String = ""
    private var currentAppName: String = ""

    private init() {}

    // MARK: - Public

    func startTracking() {
        // Listen for frontmost app changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        // Set initial frontmost app
        if let app = NSWorkspace.shared.frontmostApplication {
            currentAppBundleID = app.bundleIdentifier ?? ""
            currentAppName = app.localizedName ?? ""
        }

        // Initial data update
        updateData()

        // Periodic refresh
        startPeriodicUpdate()
    }

    func startPeriodicUpdate() {
        timer?.invalidate()
        let cfg = ConfigStore.load()
        let interval = TimeInterval(max(10, cfg.refreshFrequency))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateData()
        }
    }

    func updateData() {
        let cfg = ConfigStore.load()
        let workAppIDs = cfg.workAppBundleIDs

        // Query Screen Time database
        let appUsage = queryScreenTimeDatabase()

        var workSeconds: TimeInterval = 0
        var slackingSeconds: TimeInterval = 0

        for (bundleID, seconds) in appUsage {
            if workAppIDs.contains(bundleID) {
                workSeconds += seconds
            } else {
                slackingSeconds += seconds
            }
        }

        // Calculate total work period duration (from workStart to workEnd, minus lunch)
        let totalWorkPeriod = calculateTotalWorkPeriod(cfg: cfg)
        let availableSlacking = max(0, totalWorkPeriod - workSeconds - slackingSeconds)

        let data = SlackingData(
            currentAppBundleID: currentAppBundleID,
            currentAppName: currentAppName,
            isWorking: workAppIDs.contains(currentAppBundleID),
            workSecondsToday: workSeconds,
            slackingSecondsToday: slackingSeconds,
            availableSlackingSeconds: availableSlacking,
            lastUpdated: Date()
        )

        SlackingStore.save(data)
        SlackingStore.clearCache()
        WidgetCenter.shared.reloadTimelines(ofKind: "SlackingWidget")
    }

    // MARK: - Private

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        currentAppBundleID = app.bundleIdentifier ?? ""
        currentAppName = app.localizedName ?? ""
        updateData()
    }

    private func calculateTotalWorkPeriod(cfg: WorkConfig) -> TimeInterval {
        let startMins = cfg.workStartHour * 60 + cfg.workStartMinute
        let endMins = cfg.workEndHour * 60 + cfg.workEndMinute
        let lunchMins = (cfg.lunchEndHour * 60 + cfg.lunchEndMinute) - (cfg.lunchStartHour * 60 + cfg.lunchStartMinute)
        let workMins = max(0, endMins - startMins - max(0, lunchMins))
        return TimeInterval(workMins * 60)
    }

    private func queryScreenTimeDatabase() -> [(String, TimeInterval)] {
        let dbPath = NSHomeDirectory() + "/Library/Application Support/Knowledge/knowledgeC.db"

        // Copy to temp directory to avoid lock conflicts
        let tmpPath = NSTemporaryDirectory() + "ilovework_kc_copy.db"
        try? FileManager.default.removeItem(atPath: tmpPath)
        guard let _ = try? FileManager.default.copyItem(atPath: dbPath, toPath: tmpPath) else {
            return []
        }

        var db: OpaquePointer?
        guard sqlite3_open(tmpPath, &db) == SQLITE_OK else {
            try? FileManager.default.removeItem(atPath: tmpPath)
            return []
        }
        defer {
            sqlite3_close(db)
            try? FileManager.default.removeItem(atPath: tmpPath)
        }

        let sql = """
            SELECT ZVALUESTRING, ROUND(SUM(ZENDDATE - ZSTARTDATE), 0) AS total_seconds
            FROM ZOBJECT
            WHERE ZSTREAMNAME = '/app/usage'
              AND datetime(ZSTARTDATE + 978307200, 'unixepoch', 'localtime') >= date('now', 'localtime')
            GROUP BY ZVALUESTRING
            ORDER BY total_seconds DESC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var results: [(String, TimeInterval)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let bundleIDCStr = sqlite3_column_text(stmt, 0) {
                let bundleID = String(cString: bundleIDCStr)
                let seconds = sqlite3_column_double(stmt, 1)
                if seconds > 0 {
                    results.append((bundleID, seconds))
                }
            }
        }

        return results
    }
}

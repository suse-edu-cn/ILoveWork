import Foundation

// MARK: - Data Model

struct SlackingData {
    var currentAppBundleID: String = ""
    var currentAppName: String = ""
    var isWorking: Bool = false
    var workSecondsToday: TimeInterval = 0
    var slackingSecondsToday: TimeInterval = 0
    var availableSlackingSeconds: TimeInterval = 0
    var lastUpdated: Date = Date()
}

// MARK: - Persistence

enum SlackingStore {
    static var dataURL: URL {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        if bundleID == "com.suseoaa.ilovework.macos.SlackingWidget" {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("ilovework_slacking.txt")
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent(
                "Library/Containers/com.suseoaa.ilovework.macos.SlackingWidget/Data/Documents/ilovework_slacking.txt"
            )
        }
    }

    static func save(_ data: SlackingData) {
        var lines = [String]()
        lines.append("currentAppBundleID=\(data.currentAppBundleID)")
        lines.append("currentAppName=\(data.currentAppName)")
        lines.append("isWorking=\(data.isWorking)")
        lines.append("workSecondsToday=\(data.workSecondsToday)")
        lines.append("slackingSecondsToday=\(data.slackingSecondsToday)")
        lines.append("availableSlackingSeconds=\(data.availableSlackingSeconds)")
        lines.append("lastUpdated=\(data.lastUpdated.timeIntervalSince1970)")

        let url = dataURL
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let content = lines.joined(separator: "\n")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        if let fh = FileHandle(forWritingAtPath: url.path) {
            fh.write(Data(content.utf8))
            fh.synchronizeFile()
            fh.closeFile()
        }
    }

    static func load() -> SlackingData {
        var data = SlackingData()
        guard let content = try? String(contentsOf: dataURL, encoding: .utf8) else {
            return data
        }

        var d = [String: String]()
        for line in content.components(separatedBy: .newlines) {
            guard !line.hasPrefix("#"), !line.isEmpty else { continue }
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                d[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let v = d["currentAppBundleID"] { data.currentAppBundleID = v }
        if let v = d["currentAppName"] { data.currentAppName = v }
        if let v = d["isWorking"].flatMap(Bool.init) { data.isWorking = v }
        if let v = d["workSecondsToday"].flatMap(Double.init) { data.workSecondsToday = v }
        if let v = d["slackingSecondsToday"].flatMap(Double.init) { data.slackingSecondsToday = v }
        if let v = d["availableSlackingSeconds"].flatMap(Double.init) { data.availableSlackingSeconds = v }
        if let v = d["lastUpdated"].flatMap(Double.init) { data.lastUpdated = Date(timeIntervalSince1970: v) }

        return data
    }

    static func clearCache() {
        let widgetContainer = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.suseoaa.ilovework.macos.SlackingWidget/Data/Library/Caches")
        if let items = try? FileManager.default.contentsOfDirectory(atPath: widgetContainer.path) {
            for item in items {
                try? FileManager.default.removeItem(at: widgetContainer.appendingPathComponent(item))
            }
        }
    }
}

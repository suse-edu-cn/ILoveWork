import SwiftUI
import AppKit

struct SlackingSettingsView: View {
    @Bindable var vm: ConfigViewModel
    @State private var installedApps: [InstalledApp] = []
    @State private var searchText: String = ""
    @State private var hasFDA: Bool = false
    @State private var slackingData: SlackingData = SlackingStore.load()

    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    struct InstalledApp: Identifiable, Hashable {
        let id: String // bundle ID
        let name: String
        let icon: NSImage

        func hash(into hasher: inout Hasher) { hasher.combine(id) }
        static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool { lhs.id == rhs.id }
    }

    var filteredApps: [InstalledApp] {
        if searchText.isEmpty { return installedApps }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                // Current slacking data
                Section {
                    DataRow(label: "当前状态", value: slackingData.isWorking ? "工作中" : "摸鱼中", color: slackingData.isWorking ? .green : .orange)
                    DataRow(label: "当前应用", value: slackingData.currentAppName.isEmpty ? "无" : slackingData.currentAppName)
                    DataRow(label: "已工作", value: formatDuration(slackingData.workSecondsToday))
                    DataRow(label: "已摸鱼", value: formatDuration(slackingData.slackingSecondsToday), color: .red)
                    DataRow(label: "可摸鱼", value: formatDuration(slackingData.availableSlackingSeconds), color: slackingData.availableSlackingSeconds > 0 ? .green : .red)

                    HStack {
                        Spacer()
                        Button("刷新数据") {
                            SlackingTracker.shared.updateData()
                            slackingData = SlackingStore.load()
                        }
                        .controlSize(.small)
                    }
                } header: {
                    Label("今日数据", systemImage: "chart.bar")
                }

                // Full Disk Access status
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(hasFDA ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(hasFDA ? "已获得完全磁盘访问权限" : "未获得完全磁盘访问权限")
                                .font(.caption.bold())
                                .foregroundStyle(hasFDA ? .green : .red)
                        }

                        if !hasFDA {
                            Text("摸鱼模式需要读取系统屏幕使用时间数据，请在系统设置中授权：")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加「我爱上班」")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("打开系统设置") {
                                openFullDiskAccessSettings()
                            }
                            .controlSize(.small)
                        }
                    }
                } header: {
                    Label("权限状态", systemImage: "lock.shield")
                }

                // Work app selection
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("勾选你在工作中使用的软件，其他软件的使用时间将被记为摸鱼时间")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("搜索应用...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                    }

                    if installedApps.isEmpty {
                        ProgressView("正在扫描已安装应用...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        AppListView(apps: filteredApps, binding: binding)
                    }

                    HStack {
                        Text("已选择 \(vm.workAppBundleIDs.count) / \(installedApps.count) 个工作软件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("全选") {
                            vm.workAppBundleIDs = Set(installedApps.map(\.id))
                        }
                        .controlSize(.small)
                        Button("清空") {
                            vm.workAppBundleIDs = []
                        }
                        .controlSize(.small)
                    }
                } header: {
                    Label("工作软件", systemImage: "briefcase")
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .onAppear {
            checkFullDiskAccess()
            loadInstalledApps()
        }
        .onReceive(timer) { _ in
            slackingData = SlackingStore.load()
        }
    }

    // MARK: - Helpers

    private func binding(for bundleID: String) -> Binding<Bool> {
        Binding(
            get: { vm.workAppBundleIDs.contains(bundleID) },
            set: { isOn in
                if isOn {
                    vm.workAppBundleIDs.insert(bundleID)
                } else {
                    vm.workAppBundleIDs.remove(bundleID)
                }
            }
        )
    }

    private func checkFullDiskAccess() {
        let testPath = NSHomeDirectory() + "/Library/Application Support/Knowledge/knowledgeC.db"
        hasFDA = FileManager.default.isReadableFile(atPath: testPath)
    }

    private func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    private func loadInstalledApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = Self.scanInstalledApps()
            DispatchQueue.main.async {
                installedApps = apps
            }
        }
    }

    static func scanInstalledApps() -> [InstalledApp] {
        let fileManager = FileManager.default
        let appDirs = [
            fileManager.urls(for: .applicationDirectory, in: .localDomainMask).first!,
            fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first!,
            URL(fileURLWithPath: "/System/Applications"),
        ]

        var apps: [InstalledApp] = []
        var seenIDs = Set<String>()

        func addApps(in dir: URL) {
            guard let items = try? fileManager.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            for item in items {
                if item.pathExtension == "app" {
                    let bundle = Bundle(url: item)
                    guard let bundleID = bundle?.bundleIdentifier, !seenIDs.contains(bundleID) else { continue }
                    seenIDs.insert(bundleID)

                    let name = bundle?.infoDictionary?["CFBundleName"] as? String
                        ?? item.deletingPathExtension().lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: item.path)

                    apps.append(InstalledApp(id: bundleID, name: name, icon: icon))
                } else {
                    // Check if it's a directory (e.g. Utilities/)
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                        addApps(in: item)
                    }
                }
            }
        }

        for dir in appDirs {
            addApps(in: dir)
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)小时\(m)分钟" }
        return "\(m)分钟"
    }
}

// MARK: - App List View (adaptive columns)

private struct AppListView: View {
    let apps: [SlackingSettingsView.InstalledApp]
    let binding: (String) -> Binding<Bool>

    var body: some View {
        GeometryReader { geo in
            let columns = geo.size.width > 420
                ? [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                : [GridItem(.flexible())]

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 2) {
                    ForEach(apps) { app in
                        Toggle(isOn: binding(app.id)) {
                            HStack(spacing: 6) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 22, height: 22)
                                Text(app.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text(app.id)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .controlSize(.mini)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollDisabled(false)
        }
        .frame(height: 360)
    }
}

// MARK: - Data Row

private struct DataRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
        }
    }
}

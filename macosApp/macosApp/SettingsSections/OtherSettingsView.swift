import SwiftUI
import WidgetKit

struct OtherSettingsView: View {
    @Bindable var vm: ConfigViewModel
    @State private var notificationPermissionStatus: String = "检查中..."
    @State private var pendingNotifications: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Widget Refresh
                GroupBox(label: Label("小组件刷新", systemImage: "arrow.triangle.2.circlepath")) {
                    HStack {
                        Text("刷新频率")
                        Spacer()
                        Picker("", selection: $vm.refreshFrequency) {
                            Text("1 秒").tag(1)
                            Text("5 秒").tag(5)
                            Text("10 秒").tag(10)
                            Text("30 秒").tag(30)
                            Text("60 秒").tag(60)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    .padding(.top, 6)
                }

                // Notification Debug Panel
                GroupBox(label: Label("下班提醒状态", systemImage: "bell.badge")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("通知权限：")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notificationPermissionStatus)
                                .font(.caption.bold())
                                .foregroundStyle(notificationPermissionStatus.contains("已授权") ? .green : .red)
                        }

                        if !pendingNotifications.isEmpty {
                            Text("已计划的提醒：")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(pendingNotifications, id: \.self) { n in
                                Text("• " + n)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        } else {
                            Text("暂无已计划的提醒（请先保存配置）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Button("刷新状态") {
                                refreshNotificationStatus()
                            }
                            Button("测试通知（5秒后）") {
                                NotificationManager.shared.sendTestNotification()
                            }
                        }
                        .controlSize(.small)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(24)
        }
        .onAppear {
            refreshNotificationStatus()
        }
    }

    private func refreshNotificationStatus() {
        NotificationManager.shared.checkPermissionStatus { status in
            switch status {
            case .authorized:    notificationPermissionStatus = "✅ 已授权"
            case .denied:        notificationPermissionStatus = "❌ 已拒绝（请到系统设置 > 通知 > 我爱上班 里开启）"
            case .notDetermined: notificationPermissionStatus = "⚠️ 未决定"
            case .provisional:   notificationPermissionStatus = "⚠️ 临时授权"
            @unknown default:    notificationPermissionStatus = "❓ 未知"
            }
        }
        NotificationManager.shared.listPendingNotifications { notifications in
            pendingNotifications = notifications
        }
    }
}

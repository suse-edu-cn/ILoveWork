import SwiftUI

struct UpdateView: View {
    @StateObject private var updater = UpdaterService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Current version & refresh
                GroupBox(label: Label("软件更新", systemImage: "arrow.triangle.2.circlepath")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("检查更新与历史日志")
                                .font(.headline)
                            Text("当前版本: \(updater.currentVersion)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            Task { await updater.fetchReleases() }
                        }) {
                            if updater.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("检查更新")
                            }
                        }
                        .disabled(updater.isLoading)
                    }
                    .padding(.vertical, 6)
                }

                // Status
                if let err = updater.errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                // Latest version banner
                if let latest = updater.releases.first {
                    let isNew = isVersionNewer(latest: latest.tagName, current: updater.currentVersion)
                    if isNew {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.orange)
                            Text("发现新版本：\(latest.tagName)")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Spacer()
                            if let url = latest.macosDownloadUrl {
                                if updater.isDownloading {
                                    ProgressView("正在下载...")
                                        .controlSize(.small)
                                } else {
                                    Button("下载并安装") {
                                        Task { await updater.downloadUpdate(url: url) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    } else if !updater.releases.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("当前已是最新版本")
                        }
                        .font(.subheadline)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                // Release history list
                if !updater.releases.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(updater.releases) { release in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(release.name ?? release.tagName)
                                        .font(.headline)
                                    if release.id == updater.releases.first?.id {
                                        Text("最新")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                    Spacer()
                                    if let dateStr = release.publishedAt {
                                        Text(formatDate(dateStr))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                if let body = release.body, !body.isEmpty {
                                    Text(LocalizedStringKey(body))
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 2)
                                }

                                if let url = release.macosDownloadUrl, release.id != updater.releases.first?.id {
                                    if updater.isDownloading {
                                        ProgressView()
                                            .controlSize(.small)
                                            .padding(.top, 4)
                                    } else {
                                        Button("下载并安装") {
                                            Task { await updater.downloadUpdate(url: url) }
                                        }
                                        .font(.caption)
                                        .padding(.top, 4)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)

                            if release.id != updater.releases.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                if updater.isLoading && updater.releases.isEmpty {
                    ProgressView("正在检查更新...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if updater.releases.isEmpty && updater.errorMessage == nil {
                    Text("点击上方「检查更新」按钮获取版本信息")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(24)
        }
    }

    private func isVersionNewer(latest: String, current: String) -> Bool {
        let l = latest.replacingOccurrences(of: "v", with: "")
        let c = current.replacingOccurrences(of: "v", with: "")
        return l.compare(c, options: .numeric) == .orderedDescending
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoString) {
            let outFormatter = DateFormatter()
            outFormatter.dateStyle = .medium
            outFormatter.timeStyle = .short
            return outFormatter.string(from: date)
        }
        return isoString
    }
}

// MARK: - GitHub API Models

struct GitHubRelease: Codable, Identifiable {
    var id: Int
    var tagName: String
    var name: String?
    var body: String?
    var publishedAt: String?
    var assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case id, name, body
        case tagName = "tag_name"
        case publishedAt = "published_at"
        case assets
    }

    var macosDownloadUrl: URL? {
        let asset = assets.first { $0.name.hasSuffix(".dmg") || $0.name.hasSuffix(".zip") }
        if let urlStr = asset?.browserDownloadUrl {
            return URL(string: urlStr)
        }
        return nil
    }
}

struct GitHubAsset: Codable, Identifiable {
    var id: Int
    var name: String
    var browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case browserDownloadUrl = "browser_download_url"
    }
}

@MainActor
class UpdaterService: ObservableObject {
    static let shared = UpdaterService()

    @Published var releases: [GitHubRelease] = []
    @Published var isLoading: Bool = false
    @Published var isDownloading: Bool = false
    @Published var errorMessage: String? = nil

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func fetchReleases() async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "https://api.github.com/repos/suse-edu-cn/ILoveWork/releases") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                let decoder = JSONDecoder()
                let fetchedReleases = try decoder.decode([GitHubRelease].self, from: data)
                self.releases = fetchedReleases
            } else {
                self.errorMessage = "请求失败，可能是网络问题或接口被限制"
            }
        } catch {
            self.errorMessage = "网络请求失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func downloadUpdate(url: URL) async {
        isDownloading = true
        errorMessage = nil
        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                errorMessage = "下载失败，状态码异常"
                isDownloading = false
                return
            }

            let filename = url.lastPathComponent
            let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename.isEmpty ? "ILoveWork_Update.dmg" : filename)

            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destURL)

            NSWorkspace.shared.open(destURL)

        } catch {
            errorMessage = "下载失败: \(error.localizedDescription)"
        }
        isDownloading = false
    }
}

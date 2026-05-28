import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case basic      = "基本设置"
    case workTime   = "工作时间"
    case workMode   = "工作模式"
    case slacking   = "摸鱼模式"
    case other      = "其他"
    case update     = "软件更新"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .basic:    return "yensign.circle"
        case .workTime: return "clock"
        case .workMode: return "calendar"
        case .slacking: return "fish"
        case .other:    return "gearshape"
        case .update:   return "arrow.triangle.2.circlepath"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.allCases) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
        }
        .listStyle(.sidebar)
    }
}

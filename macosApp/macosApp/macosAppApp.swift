import SwiftUI

@main
struct macosAppApp: App {
    var body: some Scene {
        WindowGroup("ILoveWork — 打工人配置") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 580)
    }
}

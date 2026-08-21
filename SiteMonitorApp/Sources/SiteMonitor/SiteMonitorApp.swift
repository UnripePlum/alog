import SwiftUI

@main
struct SiteMonitorApp: App {
    @StateObject private var controller = MonitorController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
                .frame(minWidth: 780, minHeight: 540)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("사이트 추가") {
                    controller.requestAddTarget()
                }
                .keyboardShortcut("n")
            }
        }
    }
}

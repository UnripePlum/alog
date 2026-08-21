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
    }
}

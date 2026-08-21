import SwiftUI

@main
struct AlogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = MonitorController()
    @StateObject private var updates = UpdateService()

    var body: some Scene {
        WindowGroup(id: WindowID.main) {
            ContentView()
                .environmentObject(controller)
                .environmentObject(updates)
                .frame(minWidth: 780, minHeight: 540)
                .onAppear {
                    controller.resumeEnabled()
                    Task { await updates.check(silent: true) }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("사이트 추가") {
                    controller.requestAddTarget()
                }
                .keyboardShortcut("n")
            }
            CommandGroup(after: .appInfo) {
                Button("업데이트 확인…") {
                    Task { await updates.check(silent: false) }
                }
            }
        }

        MenuBarExtra {
            MenuBarStatusView()
                .environmentObject(controller)
                .environmentObject(updates)
                .onAppear { controller.resumeEnabled() }
        } label: {
            Image(systemName: menuBarSymbol)
        }
    }

    private var menuBarSymbol: String {
        if let last = controller.entries.first, !last.ok {
            return "exclamationmark.triangle.fill"
        }
        return controller.anyRunning ? "globe.fill" : "globe"
    }
}

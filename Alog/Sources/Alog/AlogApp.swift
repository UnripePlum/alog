import SwiftUI

@main
struct AlogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = MonitorController()

    var body: some Scene {
        WindowGroup(id: WindowID.main) {
            ContentView()
                .environmentObject(controller)
                .frame(minWidth: 780, minHeight: 540)
                .onAppear { controller.resumeEnabled() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("사이트 추가") {
                    controller.requestAddTarget()
                }
                .keyboardShortcut("n")
            }
        }

        MenuBarExtra {
            MenuBarStatusView()
                .environmentObject(controller)
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

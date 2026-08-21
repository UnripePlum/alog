import AppKit

/// 창을 닫아도 백그라운드 점검은 계속된다. 종료는 메뉴 막대/⌘Q.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

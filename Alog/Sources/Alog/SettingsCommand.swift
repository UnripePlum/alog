import SwiftUI

/// 앱 메뉴의 설정 항목. 메인 창과 같은 디스플레이에 설정 창을 연다.
struct SettingsCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("설정…") {
            openWindow(id: WindowID.settings)
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

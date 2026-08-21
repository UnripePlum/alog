import SwiftUI
import MonitorKit

/// 앱 메뉴의 정보 항목. 커스텀 About 창을 연다.
struct AboutCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("\(AppIdentity.current.displayName) 정보") {
            openWindow(id: WindowID.about)
        }
    }
}

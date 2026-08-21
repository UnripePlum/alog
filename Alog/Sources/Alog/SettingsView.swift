import SwiftUI

/// 설정 창. 탭만 조립하고 내용은 각 패인에 둔다.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem { Label("일반", systemImage: "slider.horizontal.3") }
            UpdateSettingsPane()
                .tabItem { Label("업데이트", systemImage: "arrow.triangle.2.circlepath") }
            AboutSettingsPane()
                .tabItem { Label("정보", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 520)
        .background(PlaceOnAppScreen())
    }
}

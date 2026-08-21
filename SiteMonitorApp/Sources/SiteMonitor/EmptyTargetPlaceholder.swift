import SwiftUI

/// 대상이 하나도 없을 때 가운데에 띄우는 첫 화면.
struct EmptyTargetPlaceholder: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("모니터링할 사이트를 추가하세요")
                .font(.title3)
            Text("주소만 넣으면 로드·제목·본문·스크롤을 바로 점검합니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                onAdd()
            } label: {
                Label("사이트 추가", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

/// 대상은 있지만 선택이 없을 때.
struct SelectTargetPlaceholder: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "sidebar.left")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("왼쪽에서 사이트를 선택하세요")
                .foregroundStyle(.secondary)
            Button("사이트 추가", action: onAdd)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI
import MonitorKit

/// 최소·현재·최신 세 값을 같은 형식으로 보여 준다.
struct VersionTrioView: View {
    let versions: VersionTrio

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("최소", versions.minimum.string)
            row("현재", versions.current.string)
            row("최신", versions.latest.map(\.string) ?? "확인 전")
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}

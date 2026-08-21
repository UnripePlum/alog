import SwiftUI
import MonitorKit

/// 최소·현재·최신과 GitHub Releases 업데이트.
struct UpdateSettingsPane: View {
    @EnvironmentObject var updates: UpdateService

    var body: some View {
        Form {
            Section("버전") {
                LabeledContent("최소") {
                    Text(updates.versions.minimum.string)
                        .textSelection(.enabled)
                }
                LabeledContent("현재") {
                    Text(updates.versions.current.string)
                        .textSelection(.enabled)
                }
                LabeledContent("최신") {
                    Text(updates.versions.latest.map(\.string) ?? "확인 전")
                        .textSelection(.enabled)
                }
                Button("업데이트 확인") {
                    Task { await updates.check(silent: false) }
                }
                .disabled(updates.status == .checking || updates.status == .downloading)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if case .available(let rel) = updates.status {
                    Button("\(rel.version.string) 설치") {
                        Task { await updates.installAvailable() }
                    }
                }
                if updates.isBlocked {
                    Button("최신 버전 받기") {
                        Task { await updates.installAvailable() }
                    }
                    .disabled(updates.status == .downloading)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var statusLine: String {
        if updates.isBlocked {
            switch updates.status {
            case .downloading: return "최소 버전 미달. 최신 버전을 받는 중입니다."
            case .failed(let msg): return msg
            default: return "최소 버전 \(updates.versions.minimum.string) 미만은 사용할 수 없습니다. 최신 버전을 받습니다."
            }
        }
        switch updates.status {
        case .idle: return "GitHub Releases에서 새 zip을 받습니다."
        case .checking: return "확인 중…"
        case .upToDate: return "최신 버전입니다."
        case .available(let rel): return "새 버전 \(rel.version.string)을 설치할 수 있습니다."
        case .downloading: return "받는 중… 끝나면 앱이 다시 시작됩니다."
        case .failed(let msg): return msg
        }
    }
}

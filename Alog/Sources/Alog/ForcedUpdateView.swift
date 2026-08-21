import SwiftUI
import AppKit
import MonitorKit

/// 최소 버전 미달. 점검은 막고 업데이트만 받는다.
struct ForcedUpdateView: View {
    @EnvironmentObject var updates: UpdateService
    let minimum: AppVersion
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("이 버전은 더 이상 사용할 수 없습니다")
                .font(.title2)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("최소 버전 \(minimum.string)  ·  현재 \(updates.currentVersionLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if case .downloading = updates.status {
                ProgressView("받는 중…")
            } else {
                Button("업데이트") {
                    Task { await updates.installAvailable() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

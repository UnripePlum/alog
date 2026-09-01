import SwiftUI
import AppKit
import MonitorKit

/// 최소 버전 미달. 점검은 막고 최신 zip을 받는다.
struct ForcedUpdateView: View {
    @EnvironmentObject var updates: UpdateService

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("이 버전은 더 이상 사용할 수 없습니다")
                .font(.title2)
            Text(updates.policyMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VersionTrioView(versions: updates.versions)
                .padding(.vertical, 4)
            if case .downloading = updates.status {
                ProgressView("최신 버전 받는 중…")
            } else if case .failed(let msg) = updates.status {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Button("최신 버전 다시 받기") {
                    Task { await updates.installAvailable() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                ProgressView("최신 버전 확인 중…")
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

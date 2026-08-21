import SwiftUI
import AppKit
import MonitorKit

/// 메뉴 막대: 창 없이도 점검 상태 확인·시작/중지.
struct MenuBarStatusView: View {
    @EnvironmentObject var controller: MonitorController
    @EnvironmentObject var updates: UpdateService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if updates.isBlocked {
            Text("업데이트가 필요합니다")
            Button("업데이트") {
                Task { await updates.installAvailable() }
            }
        } else {
            if controller.config.targets.isEmpty {
                Text("점검 중인 사이트가 없습니다")
            } else {
                ForEach(controller.config.targets) { target in
                    Button {
                        controller.toggle(target.id)
                    } label: {
                        Text(line(for: target))
                    }
                }
            }
            Divider()
            Button("창 열기") { openWindow(id: WindowID.main) }
            Button("사이트 추가") {
                openWindow(id: WindowID.main)
                controller.requestAddTarget()
            }
            Divider()
            Button("업데이트 확인") {
                Task { await updates.check(silent: false) }
            }
            if case .available(let rel) = updates.status {
                Button("\(rel.version.string) 설치") {
                    Task { await updates.installAvailable() }
                }
            }
        }
        Divider()
        Button("종료") { NSApplication.shared.terminate(nil) }
    }

    private func line(for target: Target) -> String {
        let mark = controller.isRunning(target.id) ? "●" : "○"
        let name = target.name.isEmpty ? target.url : target.name
        if let run = controller.latestRun(matching: target) {
            return "\(mark) \(name)  \(run.ok ? "정상" : "실패")"
        }
        return "\(mark) \(name)"
    }
}

enum WindowID {
    static let main = "main"
}

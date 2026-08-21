import SwiftUI
import MonitorKit

/// 주기/브라우저/로그 설정.
struct SettingsView: View {
    @EnvironmentObject var controller: MonitorController
    @EnvironmentObject var updates: UpdateService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("점검 주기 (랜덤 간격)") {
                    HStack {
                        Text("최소")
                        TextField("최소", value: $controller.config.schedule.minSeconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Text("초")
                        Spacer()
                    }
                    HStack {
                        Text("최대")
                        TextField("최대", value: $controller.config.schedule.maxSeconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Text("초")
                        Spacer()
                    }
                    HStack(spacing: 6) {
                        Text("빠른 설정").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        preset("5초", 3, 8)
                        preset("10초", 10, 20)
                        preset("30초", 20, 40)
                        preset("1분", 45, 90)
                    }
                    Text("사이트마다 점검이 끝나면 \(Int(controller.config.schedule.minSeconds))~\(Int(controller.config.schedule.maxSeconds))초 뒤에 다시 들어갑니다. 실행 중 바꾸면 다음 대기부터 적용됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("브라우저") {
                    Stepper(
                        "타임아웃 \(controller.config.timeoutMs)ms",
                        value: $controller.config.timeoutMs,
                        in: 1_000...120_000, step: 1_000
                    )
                    Stepper(
                        "렌더 안정화 대기 \(controller.config.settleMs)ms",
                        value: $controller.config.settleMs,
                        in: 0...10_000, step: 100
                    )
                }

                Section("관측점 (다지역 점검)") {
                    if controller.config.vantages.isEmpty {
                        Text("관측점이 없으면 로컬에서 직접 점검합니다. 프록시를 추가하면 각 대상을 관측점(지역)마다 점검합니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach($controller.config.vantages) { $v in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("이름 (예: 도쿄)", text: $v.name)
                            HStack {
                                TextField("프록시 호스트", text: $v.proxyHost)
                                    .autocorrectionDisabled()
                                TextField("포트", value: $v.proxyPort, format: .number)
                                    .frame(width: 70)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { controller.config.vantages.remove(atOffsets: $0) }

                    Button {
                        controller.config.vantages.append(
                            Vantage(name: "새 관측점", proxyHost: "", proxyPort: 8080))
                    } label: {
                        Label("관측점 추가", systemImage: "plus")
                    }

                    Text("HTTP CONNECT 프록시만 지원. 본인이 소유/권한 있는 프록시만 사용하세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("로그 파일") {
                    Text(controller.logPath)
                        .font(.caption)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }

                Section("버전") {
                    Text("현재 \(updates.currentVersionLabel)")
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
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("닫기") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 460, height: 640)
    }

    private var statusLine: String {
        switch updates.status {
        case .idle: return "GitHub Releases에서 새 zip을 받습니다."
        case .checking: return "확인 중…"
        case .upToDate: return "최신 버전입니다."
        case .available(let rel): return "새 버전 \(rel.version.string)을 설치할 수 있습니다."
        case .downloading: return "받는 중… 끝나면 앱이 다시 시작됩니다."
        case .failed(let msg): return msg
        }
    }

    private func preset(_ label: String, _ lo: Double, _ hi: Double) -> some View {
        Button(label) {
            controller.config.schedule.minSeconds = lo
            controller.config.schedule.maxSeconds = hi
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

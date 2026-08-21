import SwiftUI
import MonitorKit

/// 점검 주기·브라우저·관측점·로그 경로.
struct GeneralSettingsPane: View {
    @EnvironmentObject var controller: MonitorController

    var body: some View {
        Form {
            Section("점검 주기 (랜덤 간격)") {
                LabeledContent("최소") {
                    secondsField($controller.config.schedule.minSeconds)
                }
                LabeledContent("최대") {
                    secondsField($controller.config.schedule.maxSeconds)
                }
                HStack(spacing: 6) {
                    preset("10초", 5, 15)
                    preset("30초", 20, 40)
                    preset("1분", 45, 90)
                    preset("5분", 240, 360)
                }
                Text("다음 점검은 \(controller.config.schedule.intervalLabel) 이루어집니다. 실행 중 바꾸면 다음 대기부터 적용됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("실행기") {
                Toggle("서버에서 점검", isOn: $controller.config.remoteEngine.enabled)
                TextField(
                    "실행기 URL",
                    text: $controller.config.remoteEngine.baseURL,
                    prompt: Text(AppIdentity.current.checkAPIBaseURL)
                )
                .textContentType(.URL)
                .autocorrectionDisabled()
                Text("비우면 \(AppIdentity.current.checkAPIBaseURL) 을 씁니다. 토큰은 Application Support/\(AppIdentity.current.supportDirectoryName)/api-token 파일입니다. 끄면 로컬 WebKit으로 폴백합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach($controller.config.vantages) { $v in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("이름", text: $v.name)
                            Button(role: .destructive) {
                                controller.config.vantages.removeAll { $0.id == v.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .help("관측점 삭제")
                        }
                        HStack {
                            TextField("프록시 호스트", text: $v.proxyHost)
                                .autocorrectionDisabled()
                            TextField("포트", value: $v.proxyPort, format: .number)
                                .frame(width: 70)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Button {
                    controller.config.vantages.append(
                        Vantage(name: "새 관측점", proxyHost: "", proxyPort: 8080))
                } label: {
                    Label("관측점 추가", systemImage: "plus")
                }

                Text("HTTP CONNECT 프록시만 지원. 본인이 소유/권한 있는 프록시만 사용하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("로그 파일") {
                Text(controller.logPath)
                    .font(.caption)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    private func secondsField(_ value: Binding<Double>) -> some View {
        HStack(spacing: 4) {
            TextField("", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
            Text("초")
                .foregroundStyle(.secondary)
        }
        .fixedSize()
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

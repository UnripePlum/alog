import Foundation
import SwiftUI
import AppKit
import MonitorKit

/// 앱 상태 + 스케줄러 루프. 설정은 ConfigStore(JSON)에서 읽고 저장한다.
@MainActor
final class MonitorController: ObservableObject {
    enum PresentedSheet: String, Identifiable {
        case settings
        case add
        var id: String { rawValue }
    }

    @Published var config: AppConfig
    @Published var presentedSheet: PresentedSheet?
    @Published private(set) var runningIDs: Set<UUID> = []
    @Published private(set) var entries: [CheckRun] = []

    private let store: ConfigStore
    private let logger: JSONLLogger
    private let factory: any TargetCreating
    private var loops: [UUID: Task<Void, Never>] = [:]

    private static let maxEntries = 200

    init(factory: any TargetCreating = DefaultTargetFactory()) {
        let store = ConfigStore.defaultStore()
        self.store = store
        self.factory = factory
        self.config = store.loadOrStarter()
        self.logger = JSONLLogger(url: store.logURL)
    }

    func requestAddTarget() {
        presentedSheet = .add
    }

    func requestSettings() {
        presentedSheet = .settings
    }

    /// 이름·URL로 대상을 만들어 추가한다. 유효하지 않으면 throw.
    @discardableResult
    func addTarget(name: String, url: String) throws -> UUID {
        let target = try factory.make(name: name, url: url)
        config.targets.append(target)
        save()
        presentedSheet = nil
        return target.id
    }

    var logPath: String { logger.fileURL.path }

    /// 설정 변경 시 디스크에 저장 (진실의 원천 유지).
    func save() {
        store.save(config)
    }

    // MARK: - 대상별 개별 실행 제어

    func isRunning(_ id: UUID) -> Bool { runningIDs.contains(id) }
    var anyRunning: Bool { !runningIDs.isEmpty }

    /// 대상 하나의 독립 루프를 시작.
    func start(_ id: UUID) {
        guard !runningIDs.contains(id) else { return }
        guard config.targets.contains(where: { $0.id == id }) else { return }
        runningIDs.insert(id)
        loops[id] = Task { [weak self] in
            await self?.runLoop(for: id)
        }
    }

    /// 대상 하나의 루프를 중지.
    func stop(_ id: UUID) {
        runningIDs.remove(id)
        loops[id]?.cancel()
        loops[id] = nil
    }

    func toggle(_ id: UUID) {
        isRunning(id) ? stop(id) : start(id)
    }

    func startAll() {
        for t in config.targets { start(t.id) }
    }

    func stopAll() {
        for id in Array(runningIDs) { stop(id) }
    }

    /// 대상 하나를 즉시 1회 점검 (주기와 무관하게 지금 실행).
    func runOnceNow(_ id: UUID) {
        guard let target = config.targets.first(where: { $0.id == id }) else { return }
        Task { [weak self] in
            await self?.checkOnce(target)
        }
    }

    /// 환경변수로 요청된 경우 헤드리스 자체 점검 1회 수행 후 종료 (엔진 런타임 검증용).
    /// 일반 사용에는 영향 없음.
    func runSelfTestIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let url = env["SITEMONITOR_SELFTEST_URL"] else { return }
        let outPath = env["SITEMONITOR_SELFTEST_OUT"] ?? "/tmp/sitemonitor_selftest.txt"
        let text = env["SITEMONITOR_SELFTEST_TEXT"] ?? ""

        // 선택적 프록시(관측점) 지정: "host:port"
        var vantage: Vantage?
        if let proxy = env["SITEMONITOR_SELFTEST_PROXY"] {
            let parts = proxy.split(separator: ":")
            if parts.count == 2, let port = Int(parts[1]) {
                vantage = Vantage(name: "proxy", proxyHost: String(parts[0]), proxyPort: port)
            }
        }

        Task { @MainActor in
            let checker = WebPageChecker(timeoutMs: 15_000, settleMs: 600)
            var actions: [ActionSpec] = [
                ActionSpec(kind: .pageLoaded),
                ActionSpec(kind: .hasTitle),
                ActionSpec(kind: .bodyHasText),
                ActionSpec(kind: .scrollToBottom),
            ]
            if !text.isEmpty { actions.append(ActionSpec(kind: .checkText, text: text)) }
            let target = Target(name: "selftest", url: url, actions: actions)

            let run = await checker.runCheck(target: target, vantage: vantage)
            let lines = run.items.map {
                "\($0.actionKind.rawValue)\t\($0.ok ? "ok" : "fail")\t\($0.detail)\t\($0.durationMs)ms"
            }
            try? lines.joined(separator: "\n").write(
                toFile: outPath, atomically: true, encoding: .utf8)
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - 내부 루프

    private func makeChecker() -> Checker {
        WebPageChecker(timeoutMs: config.timeoutMs, settleMs: config.settleMs)
    }

    /// 대상 1회 테스트: 각 관측점(없으면 로컬 직접)에서 페이지 방문 + 모든 동작 점검.
    /// 관측점이 여러 개면 지역마다 결과가 1건씩 나온다.
    private func checkOnce(_ target: Target) async {
        let checker = makeChecker()
        let vantages: [Vantage?] = config.vantages.isEmpty
            ? [nil]
            : config.vantages.map { Optional($0) }
        for v in vantages {
            let run = await checker.runCheck(target: target, vantage: v)
            append(run)
        }
    }

    /// 대상 하나의 독립 루프: 테스트 → 랜덤 간격 대기 → 반복.
    private func runLoop(for id: UUID) async {
        while runningIDs.contains(id) && !Task.isCancelled {
            guard let target = config.targets.first(where: { $0.id == id }) else { break }
            await checkOnce(target)
            if !runningIDs.contains(id) { break }

            let s = config.schedule
            let lo = min(s.minSeconds, s.maxSeconds)
            let hi = max(s.minSeconds, s.maxSeconds)
            let delay = (lo == hi) ? lo : Double.random(in: lo...hi)
            try? await Task.sleep(for: .seconds(delay))
        }
    }

    private func append(_ run: CheckRun) {
        entries.insert(run, at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        logger.log(run)
    }
}

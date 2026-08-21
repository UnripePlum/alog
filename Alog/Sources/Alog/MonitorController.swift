import Foundation
import SwiftUI
import AppKit
import MonitorKit

/// 앱 상태 + 스케줄러 루프. 설정은 ConfigStore(JSON)에서 읽고 저장한다.
@MainActor
final class MonitorController: ObservableObject {
    enum PresentedSheet: String, Identifiable {
        case add
        var id: String { rawValue }
    }

    @Published var config: AppConfig {
        didSet { save() }
    }
    @Published var presentedSheet: PresentedSheet?
    @Published private(set) var runningIDs: Set<UUID> = []
    @Published private(set) var entries: [CheckRun] = []

    private let store: ConfigStore
    private let logger: JSONLLogger
    private let factory: any TargetCreating
    private var loops: [UUID: Task<Void, Never>] = [:]
    private var activity: NSObjectProtocol?

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

    /// 이름·URL로 대상을 만들어 추가한다. 추가 즉시 실제 페이지 백그라운드 점검을 시작한다.
    @discardableResult
    func addTarget(name: String, url: String) throws -> UUID {
        let target = try factory.make(name: name, url: url)
        config.targets.append(target)
        presentedSheet = nil
        start(target.id)
        return target.id
    }

    /// 켜져 있는 대상의 점검 루프를 다시 연다 (실행 시·창 재오픈).
    func resumeEnabled() {
        let ids = config.targets.filter(\.enabled).map(\.id)
        for id in ids { start(id) }
    }

    func latestRun(matching target: Target) -> CheckRun? {
        entries.first { $0.url == target.url && $0.targetName == (target.name.isEmpty ? target.url : target.name) }
    }

    var logPath: String { logger.fileURL.path }

    /// 설정 변경 시 디스크에 저장 (진실의 원천 유지).
    func save() {
        store.save(config)
    }

    // MARK: - 대상별 개별 실행 제어

    func isRunning(_ id: UUID) -> Bool { runningIDs.contains(id) }
    var anyRunning: Bool { !runningIDs.isEmpty }

    /// 대상 하나의 독립 루프를 시작. 즉시 실제 페이지를 연 뒤 랜덤 간격으로 반복.
    func start(_ id: UUID) {
        guard let idx = config.targets.firstIndex(where: { $0.id == id }) else { return }
        if !config.targets[idx].enabled {
            config.targets[idx].enabled = true
            save()
        }
        guard !runningIDs.contains(id) else { return }
        runningIDs.insert(id)
        retainActivity()
        loops[id] = Task { [weak self] in
            await self?.runLoop(for: id)
        }
    }

    /// 대상 하나의 루프를 중지. 다음 실행에서도 자동으로 켜지지 않는다.
    func stop(_ id: UUID) {
        if let idx = config.targets.firstIndex(where: { $0.id == id }),
           config.targets[idx].enabled {
            config.targets[idx].enabled = false
            save()
        }
        runningIDs.remove(id)
        loops[id]?.cancel()
        loops[id] = nil
        if runningIDs.isEmpty { releaseActivity() }
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
        guard let url = env["ALOG_SELFTEST_URL"] else { return }
        let outPath = env["ALOG_SELFTEST_OUT"] ?? "/tmp/alog_selftest.txt"
        let text = env["ALOG_SELFTEST_TEXT"] ?? ""

        var vantage: Vantage?
        if let proxy = env["ALOG_SELFTEST_PROXY"] {
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

    private func makeLocalChecker() -> any Checker {
        WebPageChecker(timeoutMs: config.timeoutMs, settleMs: config.settleMs)
    }

    /// 대상 1회 테스트. 서버 실행기가 켜져 있으면 관측점은 서버가 고르고 결과는 1건.
    /// 로컬 브라우저 폴백이면 관측점마다 1건.
    private func checkOnce(_ target: Target) async {
        if config.remoteEngine.enabled {
            append(await runRemote(target))
            return
        }
        let checker = makeLocalChecker()
        let vantages: [Vantage?] = config.vantages.isEmpty
            ? [nil]
            : config.vantages.map { Optional($0) }
        for v in vantages {
            let run = await checker.runCheck(target: target, vantage: v)
            append(run)
        }
    }

    private func runRemote(_ target: Target) async -> CheckRun {
        let support = store.url.deletingLastPathComponent()
        guard let base = RemoteChecker.resolvedBaseURL(
            config: config.remoteEngine, identity: .current
        ) else {
            return remoteSetupFailure(target, "실행기 URL이 없습니다")
        }
        guard let token = TokenResolver.resolve(supportDirectory: support) else {
            return remoteSetupFailure(
                target,
                "실행기 토큰이 없습니다. \(support.appendingPathComponent(TokenResolver.fileName).path)"
            )
        }
        let checker = RemoteChecker(
            baseURL: base,
            token: token,
            timeoutMs: config.timeoutMs,
            settleMs: config.settleMs,
            poster: URLSessionCheckPoster()
        )
        return await checker.runCheck(target: target, vantage: nil)
    }

    private func remoteSetupFailure(_ target: Target, _ detail: String) -> CheckRun {
        let items = target.actions.map {
            ActionOutcome(actionKind: $0.kind, ok: false, detail: detail, durationMs: 0)
        }
        return CheckRun(
            timestamp: Date(),
            targetName: target.name.isEmpty ? target.url : target.name,
            url: target.url,
            vantageName: "설정",
            ok: false,
            items: items,
            durationMs: 0
        )
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

    /// App Nap이 WebKit 점검을 멈추지 않게 한다. 루프가 돌 때만 유지.
    private func retainActivity() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "실제 웹페이지 백그라운드 점검"
        )
    }

    private func releaseActivity() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }
}

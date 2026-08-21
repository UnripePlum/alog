import Foundation
import WebKit
import Network
import MonitorKit

/// WebPage(WebKit-for-SwiftUI, macOS 26+) 기반 헤드리스 체커.
/// 뷰에 붙이지 않고 페이지를 로드 → 렌더 안정화 대기 → JS로 동작 수행/판정.
@MainActor
final class WebPageChecker: Checker {
    private let timeoutMs: Int
    private let settleMs: Int

    init(timeoutMs: Int, settleMs: Int) {
        self.timeoutMs = timeoutMs
        self.settleMs = settleMs
    }

    func runCheck(target: Target, vantage: Vantage?) async -> CheckRun {
        let start = Date()
        let (ok, items) = await execute(target: target, vantage: vantage)
        let duration = Int(Date().timeIntervalSince(start) * 1000)
        return CheckRun(
            timestamp: Date(),
            targetName: target.name.isEmpty ? target.url : target.name,
            url: target.url,
            vantageName: vantage?.name ?? "직접(로컬)",
            ok: ok,
            items: items,
            durationMs: duration
        )
    }

    /// 페이지를 한 번 로드하고, 설정된 모든 동작을 순서대로 점검해 항목별 결과를 모은다.
    /// vantage가 있으면 해당 HTTP CONNECT 프록시를 통해 트래픽을 내보낸다.
    private func execute(target: Target, vantage: Vantage?) async -> (Bool, [ActionOutcome]) {
        guard !target.actions.isEmpty else {
            return (false, [ActionOutcome(actionKind: .wait, ok: false, detail: "점검 동작이 없습니다", durationMs: 0)])
        }

        guard let url = URL(string: target.url), url.scheme != nil else {
            return (false, allFailed(target, "유효하지 않은 URL: \(target.url)"))
        }

        let page = makePage(vantage: vantage)
        page.load(URLRequest(url: url))

        // 실제 로드 성공/실패를 네비게이션 이벤트로 판정 (죽은 사이트 = 실패로 잡힘)
        let load = await waitForLoad(page)
        guard load.ok else {
            return (false, allFailed(target, load.detail))
        }

        // SPA 렌더 안정화 대기 (로드당 1회)
        if settleMs > 0 {
            try? await Task.sleep(for: .milliseconds(settleMs))
        }

        // 같은 페이지에서 모든 동작을 순차 수행
        var items: [ActionOutcome] = []
        var allOk = true
        for spec in target.actions {
            let t0 = Date()
            let (ok, detail) = await runAction(page, spec)
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            items.append(ActionOutcome(actionKind: spec.kind, ok: ok, detail: detail, durationMs: ms))
            if !ok { allOk = false }
        }
        return (allOk, items)
    }

    /// 로드/URL 실패 시: 설정된 각 동작을 동일 사유로 실패 처리해 항목을 보존.
    private func allFailed(_ target: Target, _ detail: String) -> [ActionOutcome] {
        target.actions.map {
            ActionOutcome(actionKind: $0.kind, ok: false, detail: detail, durationMs: 0)
        }
    }

    /// 이미 로드된 페이지에 동작 하나를 적용.
    private func runAction(_ page: WebPage, _ spec: ActionSpec) async -> (Bool, String) {
        let plan: ActionPlan
        switch ActionJS.plan(for: spec) {
        case .failure(let err):
            return (false, "설정 오류: \(err)")
        case .success(let p):
            plan = p
        }

        if plan.preDelayMs > 0 {
            try? await Task.sleep(for: .milliseconds(plan.preDelayMs))
        }

        guard let script = plan.script else {
            return (true, "대기 \(spec.ms)ms 완료")
        }

        do {
            let result = try await page.callJavaScript(script)
            let boolVal = (result as? Bool) ?? ((result as? NSNumber)?.boolValue ?? false)
            let desc = describe(spec)
            return (boolVal, boolVal ? "정상: \(desc)" : "실패: \(desc)")
        } catch {
            return (false, "JS 오류: \(error.localizedDescription)")
        }
    }

    /// 관측점(프록시)에 맞는 WebPage 생성. vantage가 없으면 로컬 직접.
    private func makePage(vantage: Vantage?) -> WebPage {
        guard let vantage else { return WebPage() }

        let store = WKWebsiteDataStore.nonPersistent()
        if let port = NWEndpoint.Port(rawValue: UInt16(clamping: vantage.proxyPort)) {
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(vantage.proxyHost), port: port)
            store.proxyConfigurations = [ProxyConfiguration(httpCONNECTProxy: endpoint)]
        }

        var config = WebPage.Configuration()
        config.websiteDataStore = store
        return WebPage(configuration: config)
    }

    /// 네비게이션 이벤트로 로드 완료(.finished) 또는 실패/타임아웃을 판정.
    private func waitForLoad(_ page: WebPage) async -> (ok: Bool, detail: String) {
        let loadTask = Task { @MainActor () -> (Bool, String) in
            do {
                for try await event in page.navigations {
                    if case .finished = event {
                        return (true, "")
                    }
                }
                return (false, "로드가 완료되지 않음")
            } catch is CancellationError {
                return (false, "타임아웃(\(timeoutMs)ms): 로드 미완료")
            } catch {
                return (false, "접속 실패: \(error.localizedDescription)")
            }
        }

        let timeoutTask = Task {
            try? await Task.sleep(for: .milliseconds(timeoutMs))
            loadTask.cancel()
        }

        let result = await loadTask.value
        timeoutTask.cancel()
        return result
    }

    private func describe(_ spec: ActionSpec) -> String {
        switch spec.kind {
        case .hasTitle: return "제목 존재"
        case .bodyHasText: return "본문 텍스트 존재"
        case .scrollToBottom: return "맨 아래까지 스크롤"
        case .pageLoaded: return "로드 완료"
        case .checkSelector: return "요소 \(spec.selector)"
        case .checkText: return "텍스트 \"\(spec.text)\""
        case .click: return "클릭 \(spec.selector)"
        case .scroll: return "스크롤 \(spec.pixels)px"
        case .wait: return "대기"
        }
    }
}

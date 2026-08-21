import Foundation
import MonitorKit

/// 설정/메뉴에서 쓰는 업데이트 상태. 네트워크는 계약에만 의존.
@MainActor
final class UpdateService: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case blocked(minimum: AppVersion, latest: AppRelease?, message: String)
        case downloading
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    let currentVersion: AppVersion
    private let checker: any UpdateChecking
    private let policyChecker: any SupportPolicyChecking
    private let policyStore: PolicyStore
    private let installer: UpdateInstaller

    var isBlocked: Bool {
        if case .blocked = status { return true }
        return false
    }

    init(
        currentVersion: AppVersion = RunningVersion.fromBundle(.main),
        checker: (any UpdateChecking)? = nil,
        policyChecker: (any SupportPolicyChecking)? = nil,
        policyStore: PolicyStore? = nil,
        installer: UpdateInstaller? = nil
    ) {
        let identity = AppIdentity.current
        let http = URLSessionHTTPClient()
        self.currentVersion = currentVersion
        self.checker = checker ?? GitHubReleaseChecker(http: http, identity: identity)
        self.policyChecker = policyChecker ?? GitHubPolicyChecker(http: http, identity: identity)
        self.policyStore = policyStore ?? .default(identity: identity)
        self.installer = installer ?? UpdateInstaller(http: http, identity: identity)
    }

    var currentVersionLabel: String { currentVersion.string }

    func check(silent: Bool = false) async {
        if !silent { status = .checking }

        var policy = policyStore.load()
        do {
            let fresh = try await policyChecker.currentPolicy()
            policyStore.save(fresh)
            policy = fresh
        } catch {
            // 원격 실패 시 캐시된 정책만 본다. 캐시도 없으면 강제하지 않음.
        }

        switch Compatibility.launchGate(current: currentVersion, policy: policy) {
        case .forceUpdate(let minimum, let message):
            let latest = try? await checker.latestRelease()
            status = .blocked(minimum: minimum, latest: latest, message: message)
            return
        case .proceed:
            break
        }

        do {
            let latest = try await checker.latestRelease()
            switch UpdatePolicy.decide(current: currentVersion, latest: latest) {
            case .upToDate:
                if !silent { status = .upToDate }
            case .available(let rel):
                status = .available(rel)
            }
        } catch {
            if !silent { status = .failed(error.localizedDescription) }
        }
    }

    func installAvailable() async {
        let release: AppRelease?
        switch status {
        case .available(let rel):
            release = rel
        case .blocked(_, let rel, _):
            release = rel
        default:
            return
        }
        guard let release else {
            status = .failed("설치할 릴리즈를 찾지 못했습니다.")
            return
        }
        status = .downloading
        do {
            let staged = try await installer.stage(release)
            try installer.replaceRunningApp(with: staged)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func dismissPrompt() {
        if case .blocked = status { return }
        if case .available = status { status = .idle }
    }
}

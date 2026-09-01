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
        case downloading
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var versions: VersionTrio
    @Published private(set) var policyMessage: String = Defaults.forcedUpdateMessage

    let currentVersion: AppVersion
    private let checker: any UpdateChecking
    private let policyChecker: any SupportPolicyChecking
    private let policyStore: PolicyStore
    private let installer: UpdateInstaller
    private var pendingRelease: AppRelease?

    var isBlocked: Bool { versions.isBelowMinimum }

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
        self.versions = .unrestricted(current: currentVersion)
        if let cached = self.policyStore.load() {
            self.versions = VersionTrio(
                current: currentVersion,
                minimum: cached.minimum,
                latest: nil
            )
            self.policyMessage = cached.message
        }
    }

    var currentVersionLabel: String { versions.current.string }

    func check(silent: Bool = false) async {
        if case .downloading = status { return }
        if !silent { status = .checking }

        var policy = policyStore.load()
        if let policy {
            versions = VersionTrio(
                current: currentVersion,
                minimum: policy.minimum,
                latest: versions.latest
            )
            if !policy.message.isEmpty { policyMessage = policy.message }
        }
        do {
            let fresh = try await policyChecker.currentPolicy()
            policyStore.save(fresh)
            policy = fresh
            versions = VersionTrio(
                current: currentVersion,
                minimum: fresh.minimum,
                latest: versions.latest
            )
            policyMessage = fresh.message.isEmpty ? Defaults.forcedUpdateMessage : fresh.message
        } catch {
            // 원격 실패 시 캐시된 정책만 본다. 캐시도 없으면 강제하지 않음.
        }

        var latest: AppRelease?
        do {
            latest = try await checker.latestRelease()
            pendingRelease = latest
            versions = VersionTrio(
                current: currentVersion,
                minimum: versions.minimum,
                latest: latest?.version
            )
        } catch {
            latest = pendingRelease
            if latest == nil, !versions.isBelowMinimum, !silent {
                status = .failed(error.localizedDescription)
                return
            }
        }

        let plan = UpdatePlan.evaluate(
            current: currentVersion,
            minimum: versions.minimum,
            latest: latest,
            message: policyMessage
        )
        switch plan {
        case .required(_, let rel, let message):
            policyMessage = message
            if let rel {
                await install(rel)
            } else if !silent || versions.isBelowMinimum {
                status = .failed("최신 버전을 찾지 못했습니다.")
            }
        case .optional(let rel):
            pendingRelease = rel
            status = .available(rel)
        case .currentIsNewest:
            pendingRelease = latest
            if !silent { status = .upToDate }
        }
    }

    func installAvailable() async {
        if case .downloading = status { return }
        if case .available(let rel) = status {
            await install(rel)
            return
        }
        if let pendingRelease {
            await install(pendingRelease)
            return
        }
        await check(silent: false)
    }

    func dismissPrompt() {
        if versions.isBelowMinimum { return }
        if case .available = status { status = .idle }
    }

    private func install(_ release: AppRelease) async {
        pendingRelease = release
        versions = VersionTrio(
            current: versions.current,
            minimum: versions.minimum,
            latest: release.version
        )
        status = .downloading
        do {
            let staged = try await installer.stage(release)
            try installer.replaceRunningApp(with: staged)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}

import Foundation
import MonitorKit

/// 설정/메뉴에서 쓰는 업데이트 상태. 네트워크는 `UpdateChecking`에만 의존.
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

    let currentVersion: AppVersion
    private let checker: any UpdateChecking
    private let installer: UpdateInstaller

    init(
        currentVersion: AppVersion = RunningVersion.fromBundle(.main),
        checker: (any UpdateChecking)? = nil,
        installer: UpdateInstaller? = nil
    ) {
        let identity = AppIdentity.current
        let http = URLSessionHTTPClient()
        self.currentVersion = currentVersion
        self.checker = checker ?? GitHubReleaseChecker(http: http, identity: identity)
        self.installer = installer ?? UpdateInstaller(http: http, identity: identity)
    }

    var currentVersionLabel: String { currentVersion.string }

    func check(silent: Bool = false) async {
        if !silent { status = .checking }
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
        guard case .available(let rel) = status else { return }
        status = .downloading
        do {
            let staged = try await installer.stage(rel)
            try installer.replaceRunningApp(with: staged)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func dismissPrompt() {
        if case .available = status { status = .idle }
    }
}

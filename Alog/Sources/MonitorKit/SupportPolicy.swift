import Foundation

/// 원격에서 최소 지원 버전을 읽는다. 나중에 값을 올리면 구버전은 점검을 멈춘다.
public protocol SupportPolicyChecking: Sendable {
    func currentPolicy() async throws -> SupportPolicy
}

public struct SupportPolicy: Codable, Equatable, Sendable {
    public var minimumVersion: String
    public var message: String

    public var minimum: AppVersion { AppVersion(minimumVersion) }

    public init(minimumVersion: String, message: String) {
        self.minimumVersion = minimumVersion
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case minimumVersion, message
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        minimumVersion = try c.decodeIfPresent(String.self, forKey: .minimumVersion)
            ?? Defaults.unrestrictedMinimum
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? Defaults.forcedUpdateMessage
    }
}

public enum LaunchGate: Equatable, Sendable {
    case proceed
    case forceUpdate(minimum: AppVersion, message: String)
}

public enum Compatibility {
    /// 정책이 없거나 최소 버전을 충족하면 사용 허용. 최신 설치 여부는 UpdatePlan이 본다.
    public static func launchGate(current: AppVersion, policy: SupportPolicy?) -> LaunchGate {
        switch UpdatePlan.evaluate(
            current: current,
            minimum: policy?.minimum,
            latest: nil,
            message: policy?.message ?? ""
        ) {
        case .required(let minimum, _, let message):
            return .forceUpdate(minimum: minimum, message: message)
        case .currentIsNewest, .optional:
            return .proceed
        }
    }
}

public struct PolicyStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static func `default`(identity: AppIdentity = .current) -> PolicyStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(identity.supportDirectoryName, isDirectory: true)
        return PolicyStore(url: dir.appendingPathComponent("support-policy.json"))
    }

    public func load() -> SupportPolicy? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SupportPolicy.self, from: data)
    }

    public func save(_ policy: SupportPolicy) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(policy) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

public struct GitHubPolicyChecker: SupportPolicyChecking {
    public var http: any HTTPClient
    public var identity: AppIdentity
    public var rawBase: URL

    public init(
        http: any HTTPClient,
        identity: AppIdentity,
        rawBase: URL = URL(string: "https://raw.githubusercontent.com")!
    ) {
        self.http = http
        self.identity = identity
        self.rawBase = rawBase
    }

    public func currentPolicy() async throws -> SupportPolicy {
        let url = Self.policyURL(rawBase: rawBase, identity: identity)
        let data = try await http.data(from: url, headers: [
            "User-Agent": identity.executableName,
        ])
        return try JSONDecoder().decode(SupportPolicy.self, from: data)
    }

    public static func policyURL(rawBase: URL, identity: AppIdentity) -> URL {
        rawBase
            .appendingPathComponent(identity.githubOwner)
            .appendingPathComponent(identity.githubRepo)
            .appendingPathComponent(identity.policyRef)
            .appendingPathComponent(identity.policyFile)
    }
}

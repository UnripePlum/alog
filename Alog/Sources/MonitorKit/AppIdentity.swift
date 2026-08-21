import Foundation

/// 앱 이름·번들 id·설정 폴더는 여기(identity.json)가 유일한 출처.
public struct AppIdentity: Codable, Sendable, Equatable {
    public var displayName: String
    public var executableName: String
    public var bundleIdentifier: String
    public var supportDirectoryName: String
    public var bundleFileName: String
    public var legacySupportDirectoryNames: [String]
    public var githubOwner: String
    public var githubRepo: String
    public var policyFile: String
    public var policyRef: String

    public static let current: AppIdentity = {
        do { return try loadBundled() }
        catch { preconditionFailure("identity.json 로드 실패: \(error)") }
    }()

    public init(
        displayName: String,
        executableName: String,
        bundleIdentifier: String,
        supportDirectoryName: String,
        bundleFileName: String,
        legacySupportDirectoryNames: [String],
        githubOwner: String,
        githubRepo: String,
        policyFile: String = Defaults.policyFile,
        policyRef: String = Defaults.policyRef
    ) {
        self.displayName = displayName
        self.executableName = executableName
        self.bundleIdentifier = bundleIdentifier
        self.supportDirectoryName = supportDirectoryName
        self.bundleFileName = bundleFileName
        self.legacySupportDirectoryNames = legacySupportDirectoryNames
        self.githubOwner = githubOwner
        self.githubRepo = githubRepo
        self.policyFile = policyFile
        self.policyRef = policyRef
    }

    enum CodingKeys: String, CodingKey {
        case displayName, executableName, bundleIdentifier
        case supportDirectoryName, bundleFileName, legacySupportDirectoryNames
        case githubOwner, githubRepo, policyFile, policyRef
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try c.decode(String.self, forKey: .displayName)
        executableName = try c.decode(String.self, forKey: .executableName)
        bundleIdentifier = try c.decode(String.self, forKey: .bundleIdentifier)
        supportDirectoryName = try c.decode(String.self, forKey: .supportDirectoryName)
        bundleFileName = try c.decode(String.self, forKey: .bundleFileName)
        legacySupportDirectoryNames = try c.decodeIfPresent([String].self, forKey: .legacySupportDirectoryNames) ?? []
        githubOwner = try c.decode(String.self, forKey: .githubOwner)
        githubRepo = try c.decode(String.self, forKey: .githubRepo)
        policyFile = try c.decodeIfPresent(String.self, forKey: .policyFile) ?? Defaults.policyFile
        policyRef = try c.decodeIfPresent(String.self, forKey: .policyRef) ?? Defaults.policyRef
    }

    public static func load(from url: URL) throws -> AppIdentity {
        try JSONDecoder().decode(AppIdentity.self, from: Data(contentsOf: url))
    }

    public static func loadBundled() throws -> AppIdentity {
        try load(from: bundledIdentityURL())
    }

    public static func bundledIdentityURL() -> URL {
        if let url = Bundle.module.url(forResource: "identity", withExtension: "json") {
            return url
        }
        preconditionFailure("MonitorKit 리소스에 identity.json 이 없습니다")
    }
}

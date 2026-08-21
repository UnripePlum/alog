import Foundation

/// 앱 이름·번들 id·설정 폴더·개발자 정보는 여기(identity.json)가 유일한 출처.
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
    public var developerName: String
    public var organization: String
    public var copyright: String
    public var homepageURL: String
    public var supportEmail: String
    /// 점검 실행기 공개 URL. 앱 설정의 remoteEngine.baseURL이 비면 이것을 쓴다.
    public var checkAPIBaseURL: String

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
        policyRef: String = Defaults.policyRef,
        developerName: String = "",
        organization: String = "",
        copyright: String = "",
        homepageURL: String = "",
        supportEmail: String = "",
        checkAPIBaseURL: String = ""
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
        self.developerName = developerName
        self.organization = organization
        self.copyright = copyright
        self.homepageURL = homepageURL
        self.supportEmail = supportEmail
        self.checkAPIBaseURL = checkAPIBaseURL
    }

    enum CodingKeys: String, CodingKey {
        case displayName, executableName, bundleIdentifier
        case supportDirectoryName, bundleFileName, legacySupportDirectoryNames
        case githubOwner, githubRepo, policyFile, policyRef
        case developerName, organization, copyright, homepageURL, supportEmail
        case checkAPIBaseURL
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
        developerName = try c.decodeIfPresent(String.self, forKey: .developerName) ?? ""
        organization = try c.decodeIfPresent(String.self, forKey: .organization) ?? ""
        copyright = try c.decodeIfPresent(String.self, forKey: .copyright) ?? ""
        homepageURL = try c.decodeIfPresent(String.self, forKey: .homepageURL) ?? ""
        supportEmail = try c.decodeIfPresent(String.self, forKey: .supportEmail) ?? ""
        checkAPIBaseURL = try c.decodeIfPresent(String.self, forKey: .checkAPIBaseURL) ?? ""
    }

    /// GitHub 저장소 페이지. host는 Defaults, 경로만 identity.
    public var repositoryURL: URL? {
        var c = URLComponents()
        c.scheme = "https"
        c.host = Defaults.githubHost
        c.path = "/\(githubOwner)/\(githubRepo)"
        return c.url
    }

    public var repositoryLabel: String {
        "\(githubOwner)/\(githubRepo)"
    }

    /// 홈페이지. 비어 있으면 저장소 URL.
    public var resolvedHomepageURL: URL? {
        let trimmed = homepageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return repositoryURL }
        return URL(string: trimmed)
    }

    public var supportMailURL: URL? {
        let trimmed = supportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = trimmed
        return c.url
    }

    public static func load(from url: URL) throws -> AppIdentity {
        try JSONDecoder().decode(AppIdentity.self, from: Data(contentsOf: url))
    }

    public static func loadBundled() throws -> AppIdentity {
        try load(from: bundledIdentityURL())
    }

    public static func bundledIdentityURL() -> URL {
        let candidates: [URL] = [
            Bundle.main.url(forResource: "identity", withExtension: "json"),
            Bundle.module.url(forResource: "identity", withExtension: "json"),
        ].compactMap { $0 }
        if let url = firstExistingIdentityFile(in: candidates) { return url }
        preconditionFailure("identity.json 이 없습니다 (앱 Resources 또는 MonitorKit 번들)")
    }

    /// 패키징된 앱은 main bundle Resources를, 테스트/swift run 은 module bundle을 쓴다.
    public static func firstExistingIdentityFile(
        in urls: [URL],
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL? {
        var seen = Set<String>()
        for url in urls {
            guard seen.insert(url.path).inserted else { continue }
            if fileExists(url) { return url }
        }
        return nil
    }
}

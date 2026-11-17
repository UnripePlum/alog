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
        if let url = firstExistingIdentityFile(from: bundledIdentityProviders) { return url }
        preconditionFailure("identity.json 이 없습니다 (앱 Resources 또는 MonitorKit 번들)")
    }

    /// 후보를 순서대로, **필요할 때만** 평가한다.
    /// `Bundle.module` 은 SwiftPM 리소스 번들을 못 찾으면 프로세스를 죽인다. 패키징된 앱에는
    /// 그 번들이 없고 빌드한 머신의 절대경로만 남으므로, 앞 후보가 있으면 건드리지 않아야 한다.
    static let bundledIdentityProviders: [() -> URL?] = [
        { Bundle.main.url(forResource: Defaults.identityResourceName, withExtension: Defaults.identityResourceExtension) },
        { Bundle.module.url(forResource: Defaults.identityResourceName, withExtension: Defaults.identityResourceExtension) },
    ]

    /// 앞 provider가 존재하는 파일을 주면 뒤 provider는 호출하지 않는다.
    public static func firstExistingIdentityFile(
        from providers: [() -> URL?],
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL? {
        for provider in providers {
            if let url = provider(), fileExists(url) { return url }
        }
        return nil
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

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

    public static let current: AppIdentity = {
        do { return try loadBundled() }
        catch { preconditionFailure("identity.json 로드 실패: \(error)") }
    }()

    public static func load(from url: URL) throws -> AppIdentity {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppIdentity.self, from: data)
    }

    public static func loadBundled() throws -> AppIdentity {
        let url = bundledIdentityURL()
        return try load(from: url)
    }

    public static func bundledIdentityURL() -> URL {
        if let url = Bundle.module.url(forResource: "identity", withExtension: "json") {
            return url
        }
        preconditionFailure("MonitorKit 리소스에 identity.json 이 없습니다")
    }
}

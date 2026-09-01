import Foundation

/// 원격에서 최신 릴리즈 정보를 가져오는 계약.
public protocol UpdateChecking: Sendable {
    func latestRelease() async throws -> AppRelease
}

/// GET / 파일 저장. 테스트는 구현체를 바꿔 네트워크 없이 검증한다.
public protocol HTTPClient: Sendable {
    func data(from url: URL, headers: [String: String]) async throws -> Data
    func download(from url: URL, to destination: URL) async throws
}

public struct AppRelease: Equatable, Sendable {
    public var version: AppVersion
    public var downloadURL: URL
    public var notes: String
    public var pageURL: URL?

    public init(version: AppVersion, downloadURL: URL, notes: String, pageURL: URL? = nil) {
        self.version = version
        self.downloadURL = downloadURL
        self.notes = notes
        self.pageURL = pageURL
    }
}

public enum UpdateDecision: Equatable, Sendable {
    case upToDate
    case available(AppRelease)
}

public enum UpdateError: Error, Equatable, Sendable, LocalizedError {
    case noZipAsset
    case badResponse
    case emptyOwnerRepo

    public var errorDescription: String? {
        switch self {
        case .noZipAsset: return "릴리즈에 설치용 zip이 없습니다."
        case .badResponse: return "업데이트 서버 응답이 올바르지 않습니다."
        case .emptyOwnerRepo: return "identity.json에 githubOwner/githubRepo가 없습니다."
        }
    }
}

public enum UpdatePolicy {
    public static func decide(current: AppVersion, latest: AppRelease) -> UpdateDecision {
        latest.version > current ? .available(latest) : .upToDate
    }
}

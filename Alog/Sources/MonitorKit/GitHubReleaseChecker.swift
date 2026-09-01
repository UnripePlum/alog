import Foundation

/// GitHub Releases `latest` JSON을 `AppRelease`로 바꾼다.
public struct GitHubReleaseChecker: UpdateChecking {
    public var http: any HTTPClient
    public var identity: AppIdentity
    public var apiBase: URL

    public init(
        http: any HTTPClient,
        identity: AppIdentity,
        apiBase: URL = URL(string: "https://api.github.com")!
    ) {
        self.http = http
        self.identity = identity
        self.apiBase = apiBase
    }

    public func latestRelease() async throws -> AppRelease {
        guard !identity.githubOwner.isEmpty, !identity.githubRepo.isEmpty else {
            throw UpdateError.emptyOwnerRepo
        }
        let url = Self.latestURL(apiBase: apiBase, identity: identity)
        let data = try await http.data(from: url, headers: [
            "Accept": "application/vnd.github+json",
            "User-Agent": identity.executableName,
        ])
        return try Self.parse(data, identity: identity)
    }

    public static func latestURL(apiBase: URL, identity: AppIdentity) -> URL {
        apiBase
            .appendingPathComponent("repos")
            .appendingPathComponent(identity.githubOwner)
            .appendingPathComponent(identity.githubRepo)
            .appendingPathComponent("releases")
            .appendingPathComponent("latest")
    }

    public static func parse(_ data: Data, identity: AppIdentity) throws -> AppRelease {
        let dto = try JSONDecoder().decode(GitHubLatest.self, from: data)
        guard let asset = pickZip(dto.assets, identity: identity),
              let download = URL(string: asset.browserDownloadURL)
        else { throw UpdateError.noZipAsset }
        return AppRelease(
            version: AppVersion(dto.tagName),
            downloadURL: download,
            notes: dto.body ?? "",
            pageURL: dto.htmlURL.flatMap(URL.init(string:))
        )
    }

    public static func pickZip(_ assets: [GitHubAsset], identity: AppIdentity) -> GitHubAsset? {
        let wanted = [
            "\(identity.bundleFileName).zip",
            "\(identity.executableName).zip",
            identity.bundleFileName.replacingOccurrences(of: " ", with: ".") + ".zip",
        ]
        if let exact = assets.first(where: { wanted.contains($0.name) }) { return exact }
        return assets.first { $0.name.lowercased().hasSuffix(".zip") }
    }
}

public struct GitHubLatest: Decodable, Sendable {
    public var tagName: String
    public var body: String?
    public var htmlURL: String?
    public var assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case htmlURL = "html_url"
        case assets
    }
}

public struct GitHubAsset: Decodable, Sendable, Equatable {
    public var name: String
    public var browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }

    public init(name: String, browserDownloadURL: String) {
        self.name = name
        self.browserDownloadURL = browserDownloadURL
    }
}

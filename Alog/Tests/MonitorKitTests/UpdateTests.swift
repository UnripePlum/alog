import XCTest
@testable import MonitorKit

final class AppVersionTests: XCTestCase {
    func testParsesVPrefixAndCompares() {
        XCTAssertEqual(AppVersion("v0.4.0.0").string, "0.4.0.0")
        XCTAssertTrue(AppVersion("0.4.0.0") < AppVersion("0.5.0.0"))
        XCTAssertTrue(AppVersion("0.4.0.0") < AppVersion("0.4.1.0"))
        XCTAssertFalse(AppVersion("0.5.0.0") < AppVersion("0.4.9.0"))
        XCTAssertEqual(AppVersion("1.0"), AppVersion("1.0.0.0"))
    }

    func testPolicy() {
        let rel = AppRelease(
            version: AppVersion("0.5.0.0"),
            downloadURL: URL(string: "https://example.com/Alog.zip")!,
            notes: ""
        )
        XCTAssertEqual(UpdatePolicy.decide(current: AppVersion("0.5.0.0"), latest: rel), .upToDate)
        if case .available(let r) = UpdatePolicy.decide(current: AppVersion("0.4.0.0"), latest: rel) {
            XCTAssertEqual(r.version, AppVersion("0.5.0.0"))
        } else {
            XCTFail("expected available")
        }
    }
}

final class GitHubReleaseParseTests: XCTestCase {
    private var identity: AppIdentity {
        AppIdentity(
            displayName: "Alog",
            executableName: "Alog",
            bundleIdentifier: "io.muinlab.alog",
            supportDirectoryName: "Alog",
            bundleFileName: "Alog",
            legacySupportDirectoryNames: [],
            githubOwner: "UnripePlum",
            githubRepo: "alog"
        )
    }

    func testParsesLatestAndPrefersNamedZip() throws {
        let json = """
        {
          "tag_name": "v0.5.0.0",
          "body": "notes here",
          "html_url": "https://github.com/UnripePlum/alog/releases/tag/v0.5.0.0",
          "assets": [
            {"name": "source.tar.gz", "browser_download_url": "https://example.com/tgz"},
            {"name": "Alog.zip", "browser_download_url": "https://example.com/Alog.zip"}
          ]
        }
        """
        let release = try GitHubReleaseChecker.parse(Data(json.utf8), identity: identity)
        XCTAssertEqual(release.version, AppVersion("0.5.0.0"))
        XCTAssertEqual(release.downloadURL.absoluteString, "https://example.com/Alog.zip")
        XCTAssertEqual(release.notes, "notes here")
    }

    func testRejectsReleaseWithoutZip() {
        let json = """
        {"tag_name":"v1.0.0","assets":[{"name":"notes.txt","browser_download_url":"https://example.com/n"}]}
        """
        XCTAssertThrowsError(try GitHubReleaseChecker.parse(Data(json.utf8), identity: identity)) { error in
            XCTAssertEqual(error as? UpdateError, .noZipAsset)
        }
    }

    func testCheckerFetchesViaHTTPClient() async throws {
        let api = URL(string: "https://api.example.test")!
        let mock = MockHTTP()
        let latestURL = GitHubReleaseChecker.latestURL(apiBase: api, identity: identity)
        mock.dataByURL[latestURL] = Data("""
        {"tag_name":"v9.0.0","assets":[{"name":"Alog.zip","browser_download_url":"https://example.com/Alog.zip"}]}
        """.utf8)
        let checker = GitHubReleaseChecker(http: mock, identity: identity, apiBase: api)
        let rel = try await checker.latestRelease()
        XCTAssertEqual(rel.version, AppVersion("9.0.0"))
    }
}

final class MockHTTP: HTTPClient, @unchecked Sendable {
    var dataByURL: [URL: Data] = [:]

    func data(from url: URL, headers: [String: String]) async throws -> Data {
        guard let data = dataByURL[url] else { throw UpdateError.badResponse }
        return data
    }

    func download(from url: URL, to destination: URL) async throws {
        let data = try await data(from: url, headers: [:])
        try data.write(to: destination)
    }
}

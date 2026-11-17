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

final class VersionPlanTests: XCTestCase {
    private func release(_ version: String) -> AppRelease {
        AppRelease(
            version: AppVersion(version),
            downloadURL: URL(string: "https://example.com/Alog.zip")!,
            notes: ""
        )
    }

    func testBelowMinimumInstallsLatest() {
        let latest = release("0.7.0.0")
        let plan = UpdatePlan.evaluate(
            current: AppVersion("0.5.0.0"),
            minimum: AppVersion("0.6.0.0"),
            latest: latest,
            message: "업데이트하세요"
        )
        guard case .required(let min, let rel, let msg) = plan else {
            return XCTFail("expected required")
        }
        XCTAssertEqual(min, AppVersion("0.6.0.0"))
        XCTAssertEqual(rel, latest)
        XCTAssertEqual(msg, "업데이트하세요")
        XCTAssertTrue(plan.shouldInstallLatest)
        XCTAssertTrue(
            VersionTrio(current: AppVersion("0.5.0.0"), minimum: AppVersion("0.6.0.0"), latest: latest.version)
                .isBelowMinimum
        )
    }

    func testBelowMinimumWithoutLatestCannotInstall() {
        let plan = UpdatePlan.evaluate(
            current: AppVersion("0.5.0.0"),
            minimum: AppVersion("0.6.0.0"),
            latest: nil,
            message: ""
        )
        guard case .required(_, let rel, let msg) = plan else {
            return XCTFail("expected required")
        }
        XCTAssertNil(rel)
        XCTAssertEqual(msg, Defaults.forcedUpdateMessage)
        XCTAssertFalse(plan.shouldInstallLatest)
    }

    func testAtOrAboveMinimumOptionalLatest() {
        let latest = release("0.7.0.0")
        let plan = UpdatePlan.evaluate(
            current: AppVersion("0.6.0.0"),
            minimum: AppVersion("0.6.0.0"),
            latest: latest,
            message: "x"
        )
        guard case .optional(let rel) = plan else {
            return XCTFail("expected optional")
        }
        XCTAssertEqual(rel.version, AppVersion("0.7.0.0"))
        XCTAssertFalse(plan.shouldInstallLatest)
    }

    func testCurrentIsNewest() {
        let latest = release("0.6.0.0")
        let plan = UpdatePlan.evaluate(
            current: AppVersion("0.6.0.0"),
            minimum: AppVersion(Defaults.unrestrictedMinimum),
            latest: latest,
            message: "x"
        )
        XCTAssertEqual(plan, .currentIsNewest)
        XCTAssertFalse(plan.shouldInstallLatest)
    }

    func testNilMinimumIsUnrestricted() {
        let plan = UpdatePlan.evaluate(
            current: AppVersion("0.1.0.0"),
            minimum: nil,
            latest: nil,
            message: "x"
        )
        XCTAssertEqual(plan, .currentIsNewest)
    }
}

final class SupportPolicyTests: XCTestCase {
    func testZeroMinimumDoesNotBlock() {
        let policy = SupportPolicy(minimumVersion: "0.0.0.0", message: "x")
        XCTAssertEqual(
            Compatibility.launchGate(current: AppVersion("0.5.0.0"), policy: policy),
            .proceed
        )
    }

    func testOlderThanMinimumIsBlocked() {
        let policy = SupportPolicy(minimumVersion: "0.6.0.0", message: "업데이트하세요")
        switch Compatibility.launchGate(current: AppVersion("0.5.0.0"), policy: policy) {
        case .forceUpdate(let min, let msg):
            XCTAssertEqual(min, AppVersion("0.6.0.0"))
            XCTAssertEqual(msg, "업데이트하세요")
        case .proceed:
            XCTFail("should block")
        }
    }

    func testMissingPolicyAllowsUse() {
        XCTAssertEqual(Compatibility.launchGate(current: AppVersion("0.1.0"), policy: nil), .proceed)
    }

    func testParsesPolicyJSONDefaults() throws {
        let json = Data("{}".utf8)
        let policy = try JSONDecoder().decode(SupportPolicy.self, from: json)
        XCTAssertEqual(policy.minimum, AppVersion("0.0.0.0"))
        XCTAssertFalse(policy.message.isEmpty)
    }

    func testPolicyCheckerURLAndFetch() async throws {
        let identity = AppIdentity(
            displayName: "Alog",
            executableName: "Alog",
            bundleIdentifier: "com.unripeplum.alog",
            supportDirectoryName: "Alog",
            bundleFileName: "Alog",
            legacySupportDirectoryNames: [],
            githubOwner: "UnripePlum",
            githubRepo: "alog"
        )
        let raw = URL(string: "https://raw.example.test")!
        let url = GitHubPolicyChecker.policyURL(rawBase: raw, identity: identity)
        XCTAssertTrue(url.absoluteString.contains("UnripePlum/alog/HEAD/update-policy.json"))
        let mock = MockHTTP()
        mock.dataByURL[url] = Data(#"{"minimumVersion":"1.2.0","message":"must update"}"#.utf8)
        let checker = GitHubPolicyChecker(http: mock, identity: identity, rawBase: raw)
        let policy = try await checker.currentPolicy()
        XCTAssertEqual(policy.minimum, AppVersion("1.2.0"))
        XCTAssertEqual(policy.message, "must update")
    }
}

final class GitHubReleaseParseTests: XCTestCase {
    private var identity: AppIdentity {
        AppIdentity(
            displayName: "Alog",
            executableName: "Alog",
            bundleIdentifier: "com.unripeplum.alog",
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

final class InstallLocationTests: XCTestCase {
    private let app = URL(fileURLWithPath: "/Apps/Some.app")

    func testWritableParentIsAccepted() {
        XCTAssertNoThrow(try InstallLocation.validate(bundleURL: app) { $0 == "/Apps" })
    }

    func testUnwritableParentIsRejectedBeforeAnythingIsRemoved() {
        XCTAssertThrowsError(try InstallLocation.validate(bundleURL: app) { _ in false }) { error in
            XCTAssertEqual(error as? UpdateError, .locationNotWritable("/Apps"))
        }
    }

    func testTranslocatedBundleIsRejectedEvenIfWritable() {
        let moved = URL(fileURLWithPath: "/private/var/folders/x\(Defaults.translocationPathMarker)ABCD/d/Some.app")
        XCTAssertThrowsError(try InstallLocation.validate(bundleURL: moved) { _ in true }) { error in
            XCTAssertEqual(error as? UpdateError, .translocated)
        }
    }
}

final class RelaunchScriptTests: XCTestCase {
    private func run(_ body: String) throws {
        let script = FileManager.default.temporaryDirectory
            .appendingPathComponent("relaunch-test-\(UUID().uuidString).sh")
        // 테스트에서는 실제 앱을 열지 않도록 open 만 무력화한다.
        try ("open() { :; }\n" + body).write(to: script, atomically: true, encoding: .utf8)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [script.path]
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()
    }

    private func makeDir(_ name: String, marker: String, in root: URL) throws -> URL {
        let dir = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try marker.write(to: dir.appendingPathComponent("marker"), atomically: true, encoding: .utf8)
        return dir
    }

    private func tempRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("relaunch it's-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private let deadPID: Int32 = 0x7FFF_FFF0

    func testSwapsStagedIntoDestinationAndDropsBackup() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let dest = try makeDir("Some.app", marker: "old", in: root)
        let staged = try makeDir("staged.app", marker: "new", in: root)
        let backup = root.appendingPathComponent(".Some.app.previous")

        try run(RelaunchScript.body(
            pid: deadPID, staged: staged.path, destination: dest.path, backup: backup.path))

        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("marker"), encoding: .utf8), "new")
        XCTAssertFalse(FileManager.default.fileExists(atPath: backup.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
    }

    func testRestoresPreviousAppWhenStagedIsMissing() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let dest = try makeDir("Some.app", marker: "old", in: root)
        let backup = root.appendingPathComponent(".Some.app.previous")

        try run(RelaunchScript.body(
            pid: deadPID,
            staged: root.appendingPathComponent("gone.app").path,
            destination: dest.path,
            backup: backup.path))

        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("marker"), encoding: .utf8), "old")
        XCTAssertFalse(FileManager.default.fileExists(atPath: backup.path))
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

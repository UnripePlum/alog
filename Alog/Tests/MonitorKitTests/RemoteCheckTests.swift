import XCTest
@testable import MonitorKit

final class RemoteCheckCodecTests: XCTestCase {
    func testRequestBodyUsesServerActionKinds() throws {
        let target = Target(
            name: "예",
            url: "https://example.com/",
            actions: [
                ActionSpec(kind: .pageLoaded),
                ActionSpec(kind: .checkText, text: "hello"),
                ActionSpec(kind: .click, selector: "a"),
            ]
        )
        let data = try RemoteCheckCodec.requestBody(
            target: target, timeoutMs: 30_000, settleMs: 1_200, vantageName: nil)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["url"] as? String, "https://example.com/")
        XCTAssertEqual(obj["targetName"] as? String, "예")
        XCTAssertEqual(obj["timeoutMs"] as? Int, 30_000)
        let actions = obj["actions"] as! [[String: Any]]
        XCTAssertEqual(actions.count, 2)
        XCTAssertEqual(actions[0]["kind"] as? String, "page_loaded")
        XCTAssertEqual(actions[1]["kind"] as? String, "check_text")
        XCTAssertEqual(actions[1]["text"] as? String, "hello")
        XCTAssertNil(actions[0]["ms"])
        XCTAssertNil(obj["vantage"])
    }

    func testCheckRunDecodesServerJSON() throws {
        let json = """
        {"timestamp":"2026-08-21T07:36:17.050827+00:00","url":"https://example.com","targetName":"example","vantageName":"house-1","ok":true,"items":[{"kind":"page_loaded","ok":true,"detail":"ok","durationMs":7}],"durationMs":2462}
        """
        let target = Target(name: "example", url: "https://example.com", actions: [])
        let run = try RemoteCheckCodec.checkRun(from: Data(json.utf8), fallbackTarget: target)
        XCTAssertTrue(run.ok)
        XCTAssertEqual(run.vantageName, "house-1")
        XCTAssertEqual(run.items.count, 1)
        XCTAssertEqual(run.items[0].actionKind, .pageLoaded)
        XCTAssertEqual(run.durationMs, 2462)
    }
}

final class RemoteEngineConfigTests: XCTestCase {
    func testLegacyEnabledTrueMeansNotLocal() throws {
        let json = #"{"enabled":true,"baseURL":""}"#
        let cfg = try JSONDecoder().decode(RemoteEngineConfig.self, from: Data(json.utf8))
        XCTAssertFalse(cfg.localMode)
        XCTAssertTrue(cfg.usesRemoteEngine)
    }

    func testLocalModeRoundTrip() throws {
        let original = RemoteEngineConfig(localMode: true, baseURL: "")
        let data = try JSONEncoder().encode(original)
        let loaded = try JSONDecoder().decode(RemoteEngineConfig.self, from: data)
        XCTAssertTrue(loaded.localMode)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNil(obj["enabled"])
        XCTAssertEqual(obj["localMode"] as? Bool, true)
    }
}

final class TokenResolverTests: XCTestCase {
    func testEnvTokenWinsOverFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "file-token\n".write(to: dir.appendingPathComponent("api-token"), atomically: true, encoding: .utf8)
        let token = TokenResolver.resolve(
            supportDirectory: dir,
            environment: [TokenResolver.envTokenKey: "env-token"]
        )
        XCTAssertEqual(token, "env-token")
    }

    func testReadsSupportDirectoryFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "file-token\n".write(to: dir.appendingPathComponent("api-token"), atomically: true, encoding: .utf8)
        let token = TokenResolver.resolve(supportDirectory: dir, environment: [:])
        XCTAssertEqual(token, "file-token")
    }
}

private struct StubPoster: CheckPoster {
    var status: Int
    var data: Data
    func post(url: URL, headers: [String: String], body: Data) async throws -> (status: Int, data: Data) {
        (status, data)
    }
}

final class RemoteCheckerTests: XCTestCase {
    func testUnauthorizedBecomesFailedRun() async {
        let checker = RemoteChecker(
            baseURL: URL(string: "https://alog.unripeplum.com")!,
            token: "x",
            timeoutMs: 1000,
            settleMs: 0,
            poster: StubPoster(status: 401, data: Data("{\"detail\":\"invalid token\"}".utf8))
        )
        let target = Target(name: "t", url: "https://example.com", actions: [ActionSpec(kind: .pageLoaded)])
        let run = await checker.runCheck(target: target, vantage: nil)
        XCTAssertFalse(run.ok)
        XCTAssertEqual(run.vantageName, "unauthorized")
    }
}

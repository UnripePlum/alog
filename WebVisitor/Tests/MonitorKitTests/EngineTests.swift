import XCTest
@testable import MonitorKit

final class RotationCursorTests: XCTestCase {
    func testRoundRobinIncrements() {
        let cursor = RotationCursor()
        let a = UUID()
        let b = UUID()
        XCTAssertEqual(cursor.next(a), 0)
        XCTAssertEqual(cursor.next(a), 1)
        XCTAssertEqual(cursor.next(b), 0)  // 대상별 독립
        XCTAssertEqual(cursor.next(a), 2)
    }
}

final class TargetCodableTests: XCTestCase {
    func testLegacyJSONDefaultsEnabled() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","name":"n","url":"https://example.com/","actions":[]}
        """
        let target = try JSONDecoder().decode(Target.self, from: Data(json.utf8))
        XCTAssertTrue(target.enabled)
        XCTAssertEqual(target.url, "https://example.com/")
    }

    func testEnabledFalseRoundTrip() throws {
        let original = Target(name: "x", url: "https://example.com/", actions: [], enabled: false)
        let data = try JSONEncoder().encode(original)
        let loaded = try JSONDecoder().decode(Target.self, from: data)
        XCTAssertFalse(loaded.enabled)
    }
}

final class AppIdentityTests: XCTestCase {
    func testBundledIdentityIsWebVisitor() throws {
        let id = try AppIdentity.loadBundled()
        XCTAssertEqual(id.displayName, "Web Visitor")
        XCTAssertEqual(id.executableName, "WebVisitor")
        XCTAssertEqual(id.bundleIdentifier, "io.muinlab.webvisitor")
        XCTAssertEqual(id.supportDirectoryName, "WebVisitor")
        XCTAssertEqual(id.bundleFileName, "Web Visitor")
        XCTAssertTrue(id.legacySupportDirectoryNames.contains("SiteMonitor"))
    }
}

final class ConfigStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("WebVisitorTest-\(UUID().uuidString)")
            .appendingPathComponent("config.json")
    }

    func testSaveLoadRoundTrip() {
        let store = ConfigStore(url: tempURL())
        let cfg = Defaults.starterConfig()
        XCTAssertTrue(store.save(cfg))
        let loaded = store.load()
        XCTAssertEqual(loaded, cfg)
    }

    func testLoadOrStarterFallsBack() {
        let store = ConfigStore(url: tempURL())
        let cfg = store.loadOrStarter()
        XCTAssertEqual(cfg.targets.count, 0)
        XCTAssertEqual(cfg.schedule.minSeconds, Defaults.minSeconds)
        XCTAssertEqual(cfg.timeoutMs, Defaults.timeoutMs)
    }

    func testMigratesLegacySupportFolderOnce() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebVisitorMigrate-\(UUID().uuidString)", isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("SiteMonitor"), withIntermediateDirectories: true)
        let old = root.appendingPathComponent("SiteMonitor/config.json")
        try Data("{\"ok\":true}".utf8).write(to: old)
        let identity = AppIdentity(
            displayName: "Web Visitor",
            executableName: "WebVisitor",
            bundleIdentifier: "io.muinlab.webvisitor",
            supportDirectoryName: "WebVisitor",
            bundleFileName: "Web Visitor",
            legacySupportDirectoryNames: ["SiteMonitor"]
        )
        let newURL = root.appendingPathComponent("WebVisitor/config.json")
        ConfigStore.migrateLegacyConfigIfNeeded(
            newConfigURL: newURL, fileManager: fm, identity: identity)
        XCTAssertEqual(try String(contentsOf: newURL, encoding: .utf8), "{\"ok\":true}")
        // 두 번째 호출은 덮어쓰지 않음
        try Data("new".utf8).write(to: newURL)
        ConfigStore.migrateLegacyConfigIfNeeded(
            newConfigURL: newURL, fileManager: fm, identity: identity)
        XCTAssertEqual(try String(contentsOf: newURL, encoding: .utf8), "new")
    }
}

final class JSONLLoggerTests: XCTestCase {
    func testLogWritesGroupedJSONL() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebVisitorLog-\(UUID().uuidString)")
            .appendingPathComponent("monitor.log")
        let logger = JSONLLogger(url: url)

        // 한 테스트 = 여러 항목이 한 줄(items 배열)로 묶여 기록됨
        let run = CheckRun(
            timestamp: Date(timeIntervalSince1970: 0),
            targetName: "t", url: "https://x/",
            ok: false,
            items: [
                ActionOutcome(actionKind: .hasTitle, ok: true, detail: "정상", durationMs: 12),
                ActionOutcome(actionKind: .bodyHasText, ok: false, detail: "실패", durationMs: 34),
            ],
            durationMs: 46)
        logger.log(run)

        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.split(separator: "\n")
        XCTAssertEqual(lines.count, 1)                       // 테스트 1회 = 1줄
        XCTAssertTrue(lines[0].contains("\"status\":\"fail\""))  // 전체 상태
        XCTAssertTrue(lines[0].contains("\"items\""))            // 항목 배열 포함
        XCTAssertTrue(lines[0].contains("has_title"))
        XCTAssertTrue(lines[0].contains("body_has_text"))
    }
}

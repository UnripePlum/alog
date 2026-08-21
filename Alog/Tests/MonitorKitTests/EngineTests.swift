import XCTest
@testable import MonitorKit

final class ScheduleConfigTests: XCTestCase {
    func testIntervalLabelUsesMinutesWhenOverAMinute() {
        let s = ScheduleConfig(minSeconds: 300, maxSeconds: 900)
        XCTAssertEqual(s.intervalLabel, "5~15분마다")
    }

    func testDefaultIntervalLabelIsSeconds() {
        let s = ScheduleConfig(minSeconds: Defaults.minSeconds, maxSeconds: Defaults.maxSeconds)
        XCTAssertEqual(s.intervalLabel, "30~90초마다")
    }

    func testIntervalLabelKeepsSecondsWhenUnderAMinute() {
        let s = ScheduleConfig(minSeconds: 10, maxSeconds: 20)
        XCTAssertEqual(s.intervalLabel, "10~20초마다")
    }
}

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
    func testBundledIdentityIsAlog() throws {
        let id = try AppIdentity.loadBundled()
        XCTAssertEqual(id.displayName, "Alog")
        XCTAssertEqual(id.executableName, "Alog")
        XCTAssertEqual(id.bundleIdentifier, "com.unripeplum.alog")
        XCTAssertEqual(id.supportDirectoryName, "Alog")
        XCTAssertEqual(id.bundleFileName, "Alog")
        XCTAssertEqual(id.githubOwner, "UnripePlum")
        XCTAssertEqual(id.githubRepo, "alog")
        XCTAssertEqual(id.policyFile, "update-policy.json")
        XCTAssertEqual(id.policyRef, "HEAD")
        XCTAssertEqual(id.developerName, "UnripePlum")
        XCTAssertEqual(id.organization, "")
        XCTAssertEqual(id.copyright, "Copyright © 2026 UnripePlum")
        XCTAssertTrue(id.legacySupportDirectoryNames.contains("SiteMonitor"))
        XCTAssertTrue(id.legacySupportDirectoryNames.contains("WebVisitor"))
        XCTAssertEqual(id.repositoryLabel, "UnripePlum/alog")
        XCTAssertEqual(id.repositoryURL?.host, Defaults.githubHost)
        XCTAssertEqual(id.repositoryURL?.path, "/UnripePlum/alog")
        XCTAssertEqual(id.resolvedHomepageURL, id.repositoryURL)
        XCTAssertNil(id.supportMailURL)
        XCTAssertEqual(id.checkAPIBaseURL, "https://alog.unripeplum.com")
    }

    func testMissingDeveloperFieldsDefaultEmpty() throws {
        let json = """
        {
          "displayName":"X","executableName":"X","bundleIdentifier":"io.x",
          "supportDirectoryName":"X","bundleFileName":"X",
          "githubOwner":"o","githubRepo":"r"
        }
        """
        let id = try JSONDecoder().decode(AppIdentity.self, from: Data(json.utf8))
        XCTAssertEqual(id.developerName, "")
        XCTAssertEqual(id.organization, "")
        XCTAssertEqual(id.copyright, "")
        XCTAssertEqual(id.homepageURL, "")
        XCTAssertEqual(id.supportEmail, "")
        XCTAssertEqual(id.checkAPIBaseURL, "")
        XCTAssertEqual(id.policyFile, Defaults.policyFile)
        XCTAssertEqual(id.repositoryURL?.path, "/o/r")
    }

    func testHomepageAndMailOverrideRepository() throws {
        let id = AppIdentity(
            displayName: "X",
            executableName: "X",
            bundleIdentifier: "io.x",
            supportDirectoryName: "X",
            bundleFileName: "X",
            legacySupportDirectoryNames: [],
            githubOwner: "o",
            githubRepo: "r",
            homepageURL: "https://example.com/app",
            supportEmail: "dev@example.com"
        )
        XCTAssertEqual(id.resolvedHomepageURL?.absoluteString, "https://example.com/app")
        XCTAssertEqual(id.supportMailURL?.scheme, "mailto")
        XCTAssertEqual(id.supportMailURL?.path, "dev@example.com")
    }

    func testIdentityFilePrefersFirstExisting() {
        let missing = URL(fileURLWithPath: "/tmp/alog-missing-identity.json")
        let present = URL(fileURLWithPath: "/tmp/alog-present-identity.json")
        let found = AppIdentity.firstExistingIdentityFile(in: [missing, present, present]) { $0 == present }
        XCTAssertEqual(found, present)
        XCTAssertNil(AppIdentity.firstExistingIdentityFile(in: [missing]) { _ in false })
    }
}

final class ConfigStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AlogTest-\(UUID().uuidString)")
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
            .appendingPathComponent("AlogMigrate-\(UUID().uuidString)", isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("SiteMonitor"), withIntermediateDirectories: true)
        let old = root.appendingPathComponent("SiteMonitor/config.json")
        try Data("{\"ok\":true}".utf8).write(to: old)
        let identity = AppIdentity(
            displayName: "Alog",
            executableName: "Alog",
            bundleIdentifier: "com.unripeplum.alog",
            supportDirectoryName: "Alog",
            bundleFileName: "Alog",
            legacySupportDirectoryNames: ["SiteMonitor", "WebVisitor"],
            githubOwner: "UnripePlum",
            githubRepo: "alog"
        )
        let newURL = root.appendingPathComponent("Alog/config.json")
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
            .appendingPathComponent("AlogLog-\(UUID().uuidString)")
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

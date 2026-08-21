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

final class ConfigStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SiteMonitorTest-\(UUID().uuidString)")
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
        // 파일 없음 → starter (UUID는 매번 새로 생성되므로 구조로 비교)
        let cfg = store.loadOrStarter()
        XCTAssertEqual(cfg.targets.count, 1)
        XCTAssertEqual(cfg.targets.first?.url, "https://example.com/")
        XCTAssertEqual(cfg.targets.first?.actions.count, 4)
    }
}

final class JSONLLoggerTests: XCTestCase {
    func testLogWritesGroupedJSONL() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SiteMonitorLog-\(UUID().uuidString)")
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

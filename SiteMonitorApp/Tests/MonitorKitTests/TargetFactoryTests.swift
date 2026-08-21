import XCTest
@testable import MonitorKit

final class TargetFactoryTests: XCTestCase {
    private let factory = DefaultTargetFactory()

    func testNormalizeAddsHTTPS() {
        XCTAssertEqual(DefaultTargetFactory.normalizeURL("example.com"), "https://example.com")
        XCTAssertEqual(DefaultTargetFactory.normalizeURL("  example.com/a  "), "https://example.com/a")
    }

    func testNormalizeKeepsScheme() {
        XCTAssertEqual(
            DefaultTargetFactory.normalizeURL("http://localhost:8765/"),
            "http://localhost:8765/"
        )
    }

    func testRejectsEmptyURL() {
        XCTAssertThrowsError(try factory.make(name: "x", url: "   ")) { error in
            XCTAssertEqual(error as? TargetFactoryError, .emptyURL)
        }
    }

    func testRejectsInvalidURL() {
        XCTAssertThrowsError(try factory.make(name: "x", url: "https://")) { error in
            XCTAssertEqual(error as? TargetFactoryError, .invalidURL)
        }
    }

    func testMakeUsesHostWhenNameBlank() throws {
        let target = try factory.make(name: "  ", url: "blog.example.com/post/1")
        XCTAssertEqual(target.name, "blog.example.com")
        XCTAssertEqual(target.url, "https://blog.example.com/post/1")
        XCTAssertEqual(target.actions.map(\.kind), Defaults.starterActions().map(\.kind))
    }

    func testMakeKeepsProvidedName() throws {
        let target = try factory.make(name: "내 사이트", url: "https://example.com/")
        XCTAssertEqual(target.name, "내 사이트")
        XCTAssertEqual(target.url, "https://example.com/")
    }
}

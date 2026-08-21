import XCTest
@testable import MonitorKit

final class ActionJSTests: XCTestCase {

    func testCheckSelectorPlan() throws {
        let spec = ActionSpec(kind: .checkSelector, selector: "#hdr")
        let plan = try ActionJS.plan(for: spec).get()
        XCTAssertEqual(plan.preDelayMs, 0)
        XCTAssertEqual(plan.script, "return document.querySelector(\"#hdr\") !== null;")
    }

    func testCheckSelectorMissing() {
        let spec = ActionSpec(kind: .checkSelector, selector: "")
        XCTAssertEqual(ActionJS.plan(for: spec), .failure(.missingSelector))
    }

    func testCheckTextPlan() throws {
        let spec = ActionSpec(kind: .checkText, text: "Welcome")
        let plan = try ActionJS.plan(for: spec).get()
        XCTAssertNotNil(plan.script)
        XCTAssertTrue(plan.script!.contains("\"Welcome\""))
        XCTAssertTrue(plan.script!.contains("includes"))
    }

    func testCheckTextMissing() {
        let spec = ActionSpec(kind: .checkText, text: "")
        XCTAssertEqual(ActionJS.plan(for: spec), .failure(.missingText))
    }

    func testClickPlan() throws {
        let spec = ActionSpec(kind: .click, selector: "button.go")
        let plan = try ActionJS.plan(for: spec).get()
        XCTAssertTrue(plan.script!.contains("\"button.go\""))
        XCTAssertTrue(plan.script!.contains(".click()"))
    }

    func testScrollPlan() throws {
        let spec = ActionSpec(kind: .scroll, pixels: 800)
        let plan = try ActionJS.plan(for: spec).get()
        XCTAssertEqual(plan.script, "window.scrollBy(0, 800); return true;")
    }

    func testWaitPlanHasNoScript() throws {
        let spec = ActionSpec(kind: .wait, ms: 750)
        let plan = try ActionJS.plan(for: spec).get()
        XCTAssertNil(plan.script)
        XCTAssertEqual(plan.preDelayMs, 750)
    }

    func testGenericPlansHaveScriptAndNoParams() throws {
        for kind in [ActionKind.hasTitle, .bodyHasText, .scrollToBottom, .pageLoaded] {
            let plan = try ActionJS.plan(for: ActionSpec(kind: kind)).get()
            XCTAssertNotNil(plan.script, "\(kind) should have a script")
            XCTAssertFalse(kind.needsParams, "\(kind) should not need params")
        }
    }

    func testHasTitlePlan() throws {
        let plan = try ActionJS.plan(for: ActionSpec(kind: .hasTitle)).get()
        XCTAssertTrue(plan.script!.contains("document.title"))
    }

    func testScrollToBottomPlan() throws {
        let plan = try ActionJS.plan(for: ActionSpec(kind: .scrollToBottom)).get()
        XCTAssertTrue(plan.script!.contains("scrollTo"))
    }

    func testJSStringEscaping() {
        // 따옴표/역슬래시가 안전하게 이스케이프되어야 함
        let out = ActionJS.jsString("a\"b\\c")
        XCTAssertEqual(out, "\"a\\\"b\\\\c\"")
    }
}

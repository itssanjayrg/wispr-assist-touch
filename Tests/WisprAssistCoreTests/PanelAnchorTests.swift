import XCTest

@testable import WisprAssistCore

final class PanelAnchorTests: XCTestCase {
    private let field = CGRect(x: 10, y: 500, width: 300, height: 30)
    private lazy var anchor = PanelAnchor(
        appKey: 42, fieldKey: 7, elementFrame: field,
        frame: CGRect(x: 0, y: 0, width: 82, height: 38))

    func testSameElementKeepsAnchor() {
        XCTAssertTrue(anchor.isValid(appKey: 42, fieldKey: 7, elementFrame: nil))
    }
    func testFieldGrowingWhileDictatingKeepsAnchor() {
        let grown = CGRect(x: 10, y: 460, width: 300, height: 70)
        XCTAssertTrue(anchor.isValid(appKey: 42, fieldKey: 99, elementFrame: grown))
    }
    func testNewAppResetsAnchor() {
        XCTAssertFalse(anchor.isValid(appKey: 43, fieldKey: 7, elementFrame: field))
    }
    func testDifferentFieldElsewhereResetsAnchor() {
        let other = CGRect(x: 10, y: 100, width: 300, height: 30)
        XCTAssertFalse(anchor.isValid(appKey: 42, fieldKey: 8, elementFrame: other))
        XCTAssertFalse(anchor.isValid(appKey: 42, fieldKey: 8, elementFrame: nil))
    }

    func testMovingKeepsHomeAndSession() {
        let moved = anchor.moved(to: CGRect(x: 40, y: 30, width: 88, height: 44))
        XCTAssertEqual(moved.frame.origin, CGPoint(x: 40, y: 30))
        XCTAssertEqual(moved.homeOrigin, anchor.homeOrigin)
        XCTAssertTrue(moved.isValid(appKey: 42, fieldKey: 7, elementFrame: nil))
        XCTAssertFalse(moved.isValid(appKey: 43, fieldKey: 7, elementFrame: field))
    }

    func testCaretJumpingFarMakesAnchorStray() {
        let a = PanelAnchor(
            appKey: 42, fieldKey: 7, elementFrame: field, frame: .zero, caret: CGPoint(x: 200, y: 600))
        XCTAssertFalse(a.strayed(to: CGPoint(x: 210, y: 620)))
        XCTAssertTrue(a.strayed(to: CGPoint(x: 20, y: 300)))
    }
    func testUserMovedPanelNeverStrays() {
        let a = PanelAnchor(
            appKey: 42, fieldKey: 7, elementFrame: field, frame: .zero, caret: CGPoint(x: 200, y: 600)
        ).moved(to: .zero)
        XCTAssertFalse(a.strayed(to: CGPoint(x: 20, y: 300)))
    }
}

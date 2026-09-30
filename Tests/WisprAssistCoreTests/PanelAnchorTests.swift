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
}

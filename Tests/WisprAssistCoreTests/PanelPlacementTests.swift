import XCTest

@testable import WisprAssistCore

final class PanelPlacementTests: XCTestCase {
    private let size = CGSize(width: 82, height: 38)
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testSingleLineFieldPlacesPanelAboveCaret() {
        let caret = CGRect(x: 500, y: 400, width: 0, height: 18)
        let field = CGRect(x: 300, y: 396, width: 400, height: 26)
        let o = PanelPlacement.origin(panelSize: size, input: .init(caret: caret, element: field), bounds: screen)
        XCTAssertEqual(o.y, field.maxY + PanelPlacement.gap, accuracy: 0.001)
        XCTAssertEqual(o.x, caret.midX - size.width / 2, accuracy: 0.001)
    }

    func testFlippedBelowClearsTheWholeField() {
        let caret = CGRect(x: 500, y: 880, width: 0, height: 18)
        let field = CGRect(x: 300, y: 870, width: 400, height: 36)
        let o = PanelPlacement.origin(panelSize: size, input: .init(caret: caret, element: field), bounds: screen)
        XCTAssertEqual(o.y + size.height + PanelPlacement.gap, field.minY, accuracy: 0.001)
    }

    func testFlipsBelowWhenNoRoomAbove() {
        let caret = CGRect(x: 500, y: 890, width: 0, height: 18)
        let o = PanelPlacement.origin(panelSize: size, input: .init(caret: caret), bounds: screen)
        XCTAssertLessThan(o.y + size.height, caret.minY)
    }

    func testMultilineAtLineEndUsesTrailingSide() {
        let caret = CGRect(x: 600, y: 500, width: 0, height: 18)
        let editor = CGRect(x: 100, y: 100, width: 900, height: 700)
        let o = PanelPlacement.origin(
            panelSize: size, input: .init(caret: caret, element: editor, isAtLineEnd: true), bounds: screen)
        XCTAssertEqual(o.x, caret.maxX + PanelPlacement.gap, accuracy: 0.001)
        XCTAssertEqual(o.y, caret.midY - size.height / 2, accuracy: 0.001)
    }

    func testMultilineMidLineUsesAbove() {
        let caret = CGRect(x: 600, y: 500, width: 0, height: 18)
        let editor = CGRect(x: 100, y: 100, width: 900, height: 700)
        let o = PanelPlacement.origin(
            panelSize: size, input: .init(caret: caret, element: editor, isAtLineEnd: false), bounds: screen)
        XCTAssertEqual(o.y, caret.maxY + PanelPlacement.gap, accuracy: 0.001)
    }

    func testClampsHorizontallyIntoBounds() {
        let caret = CGRect(x: 2, y: 400, width: 0, height: 18)
        let o = PanelPlacement.origin(panelSize: size, input: .init(caret: caret), bounds: screen)
        XCTAssertGreaterThanOrEqual(o.x, screen.minX)
        let caretR = CGRect(x: 1438, y: 400, width: 0, height: 18)
        let o2 = PanelPlacement.origin(panelSize: size, input: .init(caret: caretR), bounds: screen)
        XCTAssertLessThanOrEqual(o2.x + size.width, screen.maxX)
    }

    func testLiftMovesPanelUp() {
        let caret = CGRect(x: 500, y: 400, width: 0, height: 18)
        let o = PanelPlacement.origin(
            panelSize: size, input: .init(caret: caret, lift: PanelPlacement.terminalLift), bounds: screen)
        XCTAssertEqual(o.y, caret.maxY + PanelPlacement.gap + PanelPlacement.terminalLift, accuracy: 0.001)
    }

    func testTerminalDetection() {
        XCTAssertTrue(EditabilityRules.isTerminal(bundleID: "com.apple.Terminal"))
        XCTAssertTrue(EditabilityRules.isTerminal(bundleID: "com.googlecode.iterm2"))
        XCTAssertFalse(EditabilityRules.isTerminal(bundleID: "com.apple.Notes"))
        XCTAssertFalse(EditabilityRules.isTerminal(bundleID: nil))
    }

    func testFieldFallbackCaretEqualToElementIsSingleLine() {
        let field = CGRect(x: 300, y: 300, width: 500, height: 400)
        let o = PanelPlacement.origin(panelSize: size, input: .init(caret: field, element: field), bounds: screen)
        XCTAssertEqual(o.y, field.maxY + PanelPlacement.gap, accuracy: 0.001)
    }
}

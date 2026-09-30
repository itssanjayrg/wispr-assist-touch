import XCTest

@testable import WisprAssistCore

final class EditabilityRulesTests: XCTestCase {
    func testTextFieldWithSettableValueIsEditable() {
        XCTAssertTrue(
            EditabilityRules.isEditable(
                role: "AXTextField", subrole: nil, valueIsSettable: true, hasSelectedRange: true))
    }
    func testReadOnlyTextAreaWithoutCaretIsNotEditable() {
        XCTAssertFalse(
            EditabilityRules.isEditable(
                role: "AXTextArea", subrole: nil, valueIsSettable: false, hasSelectedRange: false))
    }
    func testTextAreaWithCaretButUnsettableValueIsEditable() {
        XCTAssertTrue(
            EditabilityRules.isEditable(
                role: "AXTextArea", subrole: nil, valueIsSettable: false, hasSelectedRange: true))
    }
    func testSecureFieldIsNeverEditable() {
        XCTAssertFalse(
            EditabilityRules.isEditable(
                role: "AXTextField", subrole: "AXSecureTextField", valueIsSettable: true, hasSelectedRange: true))
    }
    func testRichEditorWithoutSettableValueNeedsEditableFlag() {
        XCTAssertTrue(
            EditabilityRules.isEditable(
                role: "AXGroup", subrole: nil, valueIsSettable: false, hasSelectedRange: true, marksEditable: true))
        XCTAssertFalse(
            EditabilityRules.isEditable(
                role: "AXStaticText", subrole: nil, valueIsSettable: false, hasSelectedRange: true))
        XCTAssertFalse(
            EditabilityRules.isEditable(
                role: "AXGroup", subrole: nil, valueIsSettable: false, hasSelectedRange: false, marksEditable: true))
    }
    func testSecureFieldRejectedEvenIfMarkedEditable() {
        XCTAssertFalse(
            EditabilityRules.isEditable(
                role: "AXTextField", subrole: "AXSecureTextField", valueIsSettable: false, hasSelectedRange: true,
                marksEditable: true))
    }
    func testNonTextRoleNeedsCaret() {
        XCTAssertTrue(
            EditabilityRules.isEditable(role: "AXGroup", subrole: nil, valueIsSettable: true, hasSelectedRange: true))
        XCTAssertFalse(
            EditabilityRules.isEditable(role: "AXButton", subrole: nil, valueIsSettable: true, hasSelectedRange: false))
    }
}

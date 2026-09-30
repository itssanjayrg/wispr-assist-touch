import XCTest
@testable import AssistTouchCore

final class EditabilityRulesTests: XCTestCase {
    func testTextFieldWithSettableValueIsEditable() {
        XCTAssertTrue(EditabilityRules.isEditable(role: "AXTextField", subrole: nil, valueIsSettable: true, hasSelectedRange: true))
    }
    func testReadOnlyTextAreaIsNotEditable() {
        XCTAssertFalse(EditabilityRules.isEditable(role: "AXTextArea", subrole: nil, valueIsSettable: false, hasSelectedRange: true))
    }
    func testSecureFieldIsNeverEditable() {
        XCTAssertFalse(EditabilityRules.isEditable(role: "AXTextField", subrole: "AXSecureTextField", valueIsSettable: true, hasSelectedRange: true))
    }
    func testNonTextRoleNeedsCaret() {
        XCTAssertTrue(EditabilityRules.isEditable(role: "AXGroup", subrole: nil, valueIsSettable: true, hasSelectedRange: true))
        XCTAssertFalse(EditabilityRules.isEditable(role: "AXButton", subrole: nil, valueIsSettable: true, hasSelectedRange: false))
    }
}

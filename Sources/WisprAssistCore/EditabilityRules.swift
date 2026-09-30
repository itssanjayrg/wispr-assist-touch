/// Decides, from Accessibility attributes alone, whether a focused element is an
/// editable text input we should attach the control to.
public enum EditabilityRules {
    public static let textRoles: Set<String> = [
        "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"
    ]

    /// - Parameters:
    ///   - role: `AXRole` of the focused element.
    ///   - subrole: `AXSubrole` (used to reject password fields).
    ///   - valueIsSettable: whether `AXValue` can be written (i.e. it is not read-only).
    ///   - hasSelectedRange: whether the element exposes a text cursor (`AXSelectedTextRange`).
    public static func isEditable(
        role: String?,
        subrole: String?,
        valueIsSettable: Bool,
        hasSelectedRange: Bool
    ) -> Bool {
        // Privacy: never attach to password / secure input fields.
        if subrole == "AXSecureTextField" || role == "AXSecureTextField" { return false }
        guard valueIsSettable else { return false }
        if let role, textRoles.contains(role) { return true }
        // Rich editors / contenteditable regions expose other roles but still a caret.
        return hasSelectedRange
    }
}

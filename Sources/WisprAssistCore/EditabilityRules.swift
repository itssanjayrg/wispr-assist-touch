/// Decides, from Accessibility attributes alone, whether a focused element is an
/// editable text input we should attach the control to.
public enum EditabilityRules {
    public static let textRoles: Set<String> = [
        "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"
    ]

    /// Terminal emulators, whose caret is a drawn cell the panel would otherwise cover.
    public static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "dev.warp.Warp",
        "com.mitchellh.ghostty", "org.alacritty", "net.kovidgoyal.kitty", "com.github.wez.wezterm",
        "co.zeit.hyper", "io.alacritty", "com.raphaelamorim.rio", "org.tabby", "com.cmuxterm.app"
    ]

    public static func isTerminal(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return terminalBundleIDs.contains(bundleID)
    }

    /// - Parameters:
    ///   - role: `AXRole` of the focused element.
    ///   - subrole: `AXSubrole` (used to reject password fields).
    ///   - valueIsSettable: whether `AXValue` can be written (i.e. it is not read-only).
    ///   - hasSelectedRange: whether the element exposes a text cursor (`AXSelectedTextRange`).
    ///   - marksEditable: whether the element reports `AXEditable == true` (web contenteditable
    ///     regions and rich editors, whose `AXValue` is often not settable).
    public static func isEditable(
        role: String?,
        subrole: String?,
        valueIsSettable: Bool,
        hasSelectedRange: Bool,
        marksEditable: Bool = false
    ) -> Bool {
        // Privacy: never attach to password / secure input fields.
        if subrole == "AXSecureTextField" || role == "AXSecureTextField" { return false }
        // Real text inputs. Some apps (terminals, Chromium/Electron editors) report `AXValue` as
        // not settable even though the user types into them, so a caret or an editable marker
        // is accepted too. A read-only field with neither is still rejected.
        if let role, textRoles.contains(role) { return valueIsSettable || marksEditable || hasSelectedRange }
        // Rich editors / contenteditable regions expose other roles but still a caret. Read-only
        // content (static text, web pages) also exposes a selection, so require positive proof.
        return hasSelectedRange && (valueIsSettable || marksEditable)
    }
}

import AppKit
import ApplicationServices

enum AccessibilityPermission {
    private static let systemWide = AXUIElementCreateSystemWide()

    /// `AXIsProcessTrusted()` can keep answering `true` for an already-running process after the
    /// user removes it from the Accessibility list, so it is cross-checked with a live call, which
    /// fails with `.apiDisabled` the moment the permission is really gone.
    static var isTrusted: Bool {
        guard AXIsProcessTrusted() else { return false }
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &value)
        return result != .apiDisabled
    }

    /// Shows the system prompt that deep-links to Privacy & Security ▸ Accessibility.
    @discardableResult
    static func prompt() -> Bool {
        // Literal key avoids the global-var concurrency diagnostics of kAXTrustedCheckOptionPrompt.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

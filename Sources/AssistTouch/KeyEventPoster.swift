import CoreGraphics
import Foundation

/// Synthesises the two key presses the control exposes. Requires the Accessibility permission
/// (already needed for focus tracking). Events go through the HID tap, exactly as a hardware
/// key would, and the panel never becomes key, so they land in the app the user is typing in.
enum KeyEventPoster {
    private static let queue = DispatchQueue(label: "app.assisttouch.keys", qos: .userInteractive)

    private static let returnKeyCode: CGKeyCode = 36   // kVK_Return
    private static let functionKeyCode: CGKeyCode = 63 // kVK_Function (Fn / Globe)

    /// Same as pressing Return.
    static func pressReturn() {
        queue.async {
            let source = CGEventSource(stateID: .hidSystemState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: false)
            down?.flags = []
            up?.flags = []
            down?.post(tap: .cghidEventTap)
            usleep(12_000)
            up?.post(tap: .cghidEventTap)
        }
    }

    /// Same as pressing the Fn / 🌐 Globe key: a modifier-style press and release
    /// (`flagsChanged` with the secondary-Fn flag), which macOS maps to whatever the user
    /// chose under System Settings ▸ Keyboard ▸ "Press 🌐 key to".
    static func pressGlobe() {
        queue.async {
            let source = CGEventSource(stateID: .hidSystemState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: functionKeyCode, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: functionKeyCode, keyDown: false)
            down?.type = .flagsChanged
            down?.flags = .maskSecondaryFn
            up?.type = .flagsChanged
            up?.flags = []
            down?.post(tap: .cghidEventTap)
            usleep(40_000)
            up?.post(tap: .cghidEventTap)
        }
    }
}

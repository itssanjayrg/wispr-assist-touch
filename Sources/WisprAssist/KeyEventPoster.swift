import CoreGraphics
import Foundation

/// Synthesises the two key presses the control exposes. Requires the Accessibility permission
/// (already needed for focus tracking). Events go through the HID tap, exactly as a hardware
/// key would, and the panel never becomes key, so they land in the app the user is typing in.
enum KeyEventPoster {
    private static let queue = DispatchQueue(label: "app.wisprassist.keys", qos: .userInteractive)

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

    /// The Globe / Fn key is held for exactly as long as the on-screen button is held, like the
    /// physical key (macOS maps press / hold / double-press to whatever the user chose under
    /// System Settings ▸ Keyboard, and dictation tools such as Wispr Flow watch for the hold).
    /// State is only touched on `queue`, which also guarantees down/up are posted in order and
    /// that an "up" is never sent without a matching "down".
    private static var globeHeld = false

    static func globeDown() {
        queue.async {
            guard !globeHeld else { return }
            globeHeld = true
            postGlobe(down: true)
        }
    }

    static func globeUp() {
        queue.async {
            guard globeHeld else { return }
            globeHeld = false
            postGlobe(down: false)
        }
    }

    private static func postGlobe(down: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: functionKeyCode, keyDown: down) else { return }
        event.type = .flagsChanged
        event.flags = down ? .maskSecondaryFn : []
        event.post(tap: .cghidEventTap)
    }
}

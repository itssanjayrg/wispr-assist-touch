import AppKit
import SwiftUI

/// Borderless, non-activating panel: it floats above the active app but can never become
/// key or main, so the text field the user is typing in keeps keyboard focus at all times.
final class FloatingPanel: NSPanel {
    init(onGlobe: @escaping () -> Void, onReturn: @escaping () -> Void) {
        let size = Metrics.panelSize
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)

        title = "Assist Touch"
        isFloatingPanel = true
        level = .statusBar
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active            // stay vibrant even though the window is never key
        effect.maskImage = Self.roundedMask(radius: Metrics.outerRadius)
        effect.autoresizingMask = [.width, .height]

        let hosting = FirstMouseHostingView(rootView: ControlView(onGlobe: onGlobe, onReturn: onReturn))
        hosting.frame = effect.bounds
        hosting.autoresizingMask = [.width, .height]
        effect.addSubview(hosting)

        // Hairline edge, like system HUDs.
        effect.wantsLayer = true
        contentView = effect
        setAccessibilityLabel("Assist Touch controls")
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Stretchable rounded-rect mask; also gives the window shadow the correct shape.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    required init(rootView: Content) { super.init(rootView: rootView) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

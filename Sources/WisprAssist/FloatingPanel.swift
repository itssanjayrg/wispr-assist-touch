import AppKit
import SwiftUI

/// Borderless, non-activating panel: it floats above the active app but can never become
/// key or main, so the text field the user is typing in keeps keyboard focus at all times.
final class FloatingPanel: NSPanel {
    /// Reported to the controller, which decides where the panel may actually go.
    enum HandleDrag {
        case began
        case moved(origin: CGPoint)
        case ended
    }

    private let onGlobeRightClick: () -> Void
    private let onHandleDrag: (HandleDrag) -> Void
    private let handleState: HandleState
    private var dragStartMouse: CGPoint?
    private var dragStartOrigin = CGPoint.zero

    init(
        onGlobeDown: @escaping () -> Void, onGlobeUp: @escaping () -> Void,
        onGlobeRightClick: @escaping () -> Void, onDeleteLine: @escaping () -> Void,
        onHandleDrag: @escaping (HandleDrag) -> Void, onNudge: @escaping (CGSize) -> Void
    ) {
        self.onGlobeRightClick = onGlobeRightClick
        self.onHandleDrag = onHandleDrag
        let state = HandleState()
        self.handleState = state
        let size = Metrics.windowSize
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true)

        title = "Wispr Assist"
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

        // Transparent container (window-sized) so the move handle can overhang the pill.
        let container = NSView(frame: NSRect(origin: .zero, size: size))

        let effect = NSVisualEffectView(frame: Metrics.pillRect)
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active  // stay vibrant even though the window is never key
        effect.maskImage = Self.roundedMask(radius: Metrics.outerRadius)
        container.addSubview(effect)

        let hosting = FirstMouseHostingView(
            rootView: ControlView(
                handleState: state, onGlobeDown: onGlobeDown, onGlobeUp: onGlobeUp,
                onDeleteLine: onDeleteLine, onNudge: onNudge))
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)

        contentView = container
        setAccessibilityLabel("Wispr Assist controls")
    }

    /// Mouse handling SwiftUI can't do for a panel that is never key: right-click on the Globe button
    /// acts as Return, and dragging the move handle repositions the panel.
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .rightMouseDown:
            return
        case .rightMouseUp:
            if Metrics.globeButtonRect.contains(event.locationInWindow) { onGlobeRightClick() }
            return
        case .leftMouseDown where isOnHandle(event.locationInWindow):
            dragStartMouse = NSEvent.mouseLocation
            dragStartOrigin = frame.origin
            handleState.isDragging = true
            onHandleDrag(.began)
        case .leftMouseDragged where dragStartMouse != nil:
            guard let start = dragStartMouse else { return }
            let mouse = NSEvent.mouseLocation
            onHandleDrag(
                .moved(
                    origin: CGPoint(
                        x: dragStartOrigin.x + mouse.x - start.x,
                        y: dragStartOrigin.y + mouse.y - start.y)))
        case .leftMouseUp where dragStartMouse != nil:
            dragStartMouse = nil
            handleState.isDragging = false
            onHandleDrag(.ended)
        default:
            super.sendEvent(event)
        }
    }

    private func isOnHandle(_ point: CGPoint) -> Bool {
        let c = Metrics.handleCenter
        return hypot(point.x - c.x, point.y - c.y) <= Metrics.handleDiameter / 2
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

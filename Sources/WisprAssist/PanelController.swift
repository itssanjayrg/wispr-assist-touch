import AppKit
import WisprAssistCore

/// Owns the panel: converts snapshots to screen positions, animates show / move / hide, and
/// debounces hiding so brief focus hand-offs (tabbing between fields) never flicker.
final class PanelController {
    private lazy var panel = FloatingPanel(
        onGlobeDown: { KeyEventPoster.globeDown() },
        onGlobeUp: { KeyEventPoster.globeUp() },
        onGlobeRightClick: { KeyEventPoster.pressReturn() },
        onDeleteLine: { KeyEventPoster.pressDeleteLine() }
    )

    private var isShown = false
    private var targetFrame = NSRect.zero
    private var hideWork: DispatchWorkItem?
    private var visibilityToken = 0
    /// Where the panel landed for the current field; it stays there while typing continues.
    private var anchor: PanelAnchor?
    /// When the panel last hid. Dictation often blanks focus for a moment, so the anchor survives
    /// a short gap; after a longer one (user went elsewhere and came back) it is forgotten.
    private var hiddenAt: Date?
    private static let anchorGrace: TimeInterval = 2

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    func update(_ snapshot: FocusSnapshot?, immediately: Bool = false) {
        guard let snapshot else {
            scheduleHide(immediately: immediately)
            return
        }
        if let hiddenAt, Date().timeIntervalSince(hiddenAt) > Self.anchorGrace { anchor = nil }
        if let anchor,
            anchor.isValid(
                appKey: snapshot.appKey, fieldKey: snapshot.fieldKey,
                elementFrame: snapshot.elementFrame)
        {
            hiddenAt = nil
            present(at: anchor.frame)
            return
        }
        DebugLog.note("ANCHOR new placement (\(anchor == nil ? "no anchor" : "different field/app"))")
        guard let frame = placement(for: snapshot) else {
            scheduleHide(immediately: immediately)
            return
        }
        anchor = PanelAnchor(
            appKey: snapshot.appKey, fieldKey: snapshot.fieldKey,
            elementFrame: snapshot.elementFrame, frame: frame)
        hiddenAt = nil
        present(at: frame)
    }

    // MARK: - Placement

    private func placement(for snapshot: FocusSnapshot) -> NSRect? {
        guard let primary = NSScreen.screens.first else { return nil }
        let caret = cocoaRect(snapshot.caretRect, primaryHeight: primary.frame.height)
        let element = snapshot.elementFrame.map { cocoaRect($0, primaryHeight: primary.frame.height) }

        let center = CGPoint(x: caret.midX, y: caret.midY)
        guard
            let screen = NSScreen.screens.first(where: { $0.frame.contains(center) })
                ?? NSScreen.screens.first(where: { $0.frame.intersects(caret) })
        else { return nil }

        let size = Metrics.panelSize
        let origin = PanelPlacement.origin(
            panelSize: size,
            input: PlacementInput(
                caret: caret, element: element, isAtLineEnd: snapshot.isAtLineEnd, lift: snapshot.lift),
            bounds: screen.visibleFrame.insetBy(dx: 8, dy: 8)
        )
        let scale = screen.backingScaleFactor
        let snapped = CGPoint(x: (origin.x * scale).rounded() / scale, y: (origin.y * scale).rounded() / scale)
        return NSRect(origin: snapped, size: size)
    }

    /// Accessibility space (top-left origin) → Cocoa space (bottom-left origin).
    private func cocoaRect(_ r: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    // MARK: - Show / move / hide

    private func present(at frame: NSRect) {
        hideWork?.cancel()
        hideWork = nil
        visibilityToken &+= 1

        if !isShown {
            isShown = true
            targetFrame = frame
            if !panel.isVisible { panel.alphaValue = 0 }
            panel.setFrame(frame, display: false)
            panel.orderFrontRegardless()
            panel.invalidateShadow()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
            return
        }

        guard frame != targetFrame else { return }
        targetFrame = frame
        if reduceMotion {
            panel.setFrame(frame, display: true)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(frame, display: true)
            }
        }
    }

    private func scheduleHide(immediately: Bool) {
        guard isShown else { return }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (immediately ? 0 : 0.18), execute: work)
    }

    private func hide() {
        guard isShown else { return }
        isShown = false
        hideWork = nil
        hiddenAt = Date()
        KeyEventPoster.globeUp()  // never leave Fn stuck down if the panel goes away mid-hold
        visibilityToken &+= 1
        let token = visibilityToken
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            },
            completionHandler: { [weak self] in
                guard let self, !self.isShown, token == self.visibilityToken else { return }
                self.panel.orderOut(nil)
            })
    }
}

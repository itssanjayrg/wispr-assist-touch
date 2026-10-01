import AppKit
import WisprAssistCore

/// Owns the panel: converts snapshots to screen positions, animates show / move / hide, and
/// debounces hiding so brief focus hand-offs (tabbing between fields) never flicker.
final class PanelController {
    private lazy var panel = FloatingPanel(
        onGlobeDown: { KeyEventPoster.globeDown() },
        onGlobeUp: { KeyEventPoster.globeUp() },
        onGlobeRightClick: { KeyEventPoster.pressReturn() },
        onDeleteLine: { KeyEventPoster.pressDeleteLine() },
        onHandleDrag: { [weak self] drag in self?.handleDrag(drag) },
        onNudge: { [weak self] delta in self?.nudge(delta) }
    )

    private var isShown = false
    /// True while the user is dragging the move handle: automatic placement and hiding are paused.
    private var isDragging = false
    private var cursorPushed = false
    private var panelCreated = false
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
        if isDragging { return }  // the user is positioning the panel; leave it alone
        guard let snapshot else {
            scheduleHide(immediately: immediately)
            return
        }
        if let hiddenAt, Date().timeIntervalSince(hiddenAt) > Self.anchorGrace { anchor = nil }
        let caretPoint = CGPoint(x: snapshot.caretRect.midX, y: snapshot.caretRect.midY)
        if let anchor,
            anchor.isValid(
                appKey: snapshot.appKey, fieldKey: snapshot.fieldKey,
                elementFrame: snapshot.elementFrame),
            !anchor.strayed(to: caretPoint)
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
            elementFrame: snapshot.elementFrame, frame: frame, caret: caretPoint)
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

        let size = Metrics.pillSize
        let origin = PanelPlacement.origin(
            panelSize: size,
            input: PlacementInput(
                caret: caret, element: element, isAtLineEnd: snapshot.isAtLineEnd, lift: snapshot.lift),
            bounds: screen.visibleFrame.insetBy(dx: 8, dy: 8)
        )
        let scale = screen.backingScaleFactor
        let snapped = CGPoint(x: (origin.x * scale).rounded() / scale, y: (origin.y * scale).rounded() / scale)
        // The window extends left of the pill (for the move handle); the pill itself stays put.
        return NSRect(
            origin: CGPoint(x: snapped.x - Metrics.handleOverhang, y: snapped.y), size: Metrics.windowSize)
    }

    /// Accessibility space (top-left origin) → Cocoa space (bottom-left origin).
    private func cocoaRect(_ r: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    // MARK: - Moving the panel by its handle

    func handleDrag(_ drag: FloatingPanel.HandleDrag) {
        switch drag {
        case .began:
            isDragging = true
            hideWork?.cancel()
            hideWork = nil
            NSCursor.closedHand.push()
            cursorPushed = true
        case .moved(let origin):
            guard isDragging else { return }
            panel.setFrameOrigin(clampedOrigin(origin))
        case .ended:
            releaseCursor()
            guard isDragging else { return }
            isDragging = false
            commitUserPosition()
        }
    }

    /// Keyboard / VoiceOver alternative to dragging: nudges the panel by `delta` points.
    func nudge(_ delta: CGSize) {
        guard isShown, !isDragging else { return }
        let o = panel.frame.origin
        panel.setFrameOrigin(clampedOrigin(CGPoint(x: o.x + delta.width, y: o.y + delta.height)))
        commitUserPosition()
    }

    /// The moved position becomes this session's anchor, so it survives caret moves and dictation but
    /// not a new field or app (see `PanelAnchor`).
    private func commitUserPosition() {
        targetFrame = panel.frame
        anchor = anchor?.moved(to: panel.frame)
    }

    private func clampedOrigin(_ proposed: CGPoint) -> CGPoint {
        let size = Metrics.windowSize
        let center = CGPoint(x: proposed.x + size.width / 2, y: proposed.y + size.height / 2)
        let screen =
            NSScreen.screens.first(where: { $0.frame.contains(center) })
            ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) ?? NSScreen.main
        guard let screen else { return proposed }
        return PanelDrag.clamp(
            origin: proposed, size: size, home: anchor?.homeOrigin ?? panel.frame.origin,
            bounds: screen.visibleFrame.insetBy(dx: 4, dy: 4))
    }

    private func releaseCursor() {
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
    }

    // MARK: - Show / move / hide

    private func present(at frame: NSRect) {
        hideWork?.cancel()
        hideWork = nil
        visibilityToken &+= 1

        if !isShown {
            isShown = true
            panelCreated = true
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

    /// Removes the panel at once, with no fade and no debounce. Used when tracking stops (permission
    /// revoked, feature switched off, app quitting) so a stale panel can never be left on screen.
    func hideNow() {
        isDragging = false
        releaseCursor()
        hideWork?.cancel()
        hideWork = nil
        visibilityToken &+= 1  // invalidates any fade-out completion still in flight
        isShown = false
        hiddenAt = Date()
        KeyEventPoster.globeUp()
        guard panelCreated else { return }
        panel.orderOut(nil)
        panel.alphaValue = 0
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

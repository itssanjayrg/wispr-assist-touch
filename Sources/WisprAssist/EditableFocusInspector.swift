import AppKit
import ApplicationServices
import WisprAssistCore

/// What we know about the focused text input. Rects are in Accessibility screen space
/// (origin top-left of the primary display, y grows downward).
struct FocusSnapshot: Equatable {
    var caretRect: CGRect
    var elementFrame: CGRect?
    var isAtLineEnd: Bool
    /// Extra upward offset for the panel (terminals).
    var lift: CGFloat = 0
    /// Process and element identity of the focused field (see `PanelAnchor`).
    var appKey: Int = 0
    var fieldKey: Int = 0
}

/// Reads the focused element through the Accessibility API. Not thread-affine: it is called
/// from a background queue so a hung target app can never block the UI.
final class EditableFocusInspector {
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let systemWide = AXUIElementCreateSystemWide()
    private var lastCaret: (pid: pid_t, frame: CGRect?, rect: CGRect, atLineEnd: Bool, time: Date)?

    init() {
        // Never wait long on an unresponsive app.
        AXUIElementSetMessagingTimeout(systemWide, 0.25)
    }

    func snapshot(frontmostPID: pid_t?) -> FocusSnapshot? {
        guard let element = focusedElement(frontmostPID: frontmostPID) else {
            let id = frontmostPID.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }
            DebugLog.note("no focused element in \(id ?? "?")")
            return nil
        }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid != ownPID else { return nil }
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier

        let role = stringValue(element, kAXRoleAttribute)
        let subrole = stringValue(element, kAXSubroleAttribute)
        let selection = selectedRange(of: element)

        var settable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)

        // `AXEditable` (native/WebKit) or an editable ancestor (Chromium contenteditable).
        let marksEditable =
            (copy(element, "AXEditable") as? Bool) == true
            || copy(element, "AXHighestEditableAncestor") != nil
            || copy(element, "AXEditableAncestor") != nil

        let describe =
            "\(bundleID ?? "?") role=\(role ?? "nil") sub=\(subrole ?? "nil") settable=\(settable.boolValue) sel=\(selection != nil) editable=\(marksEditable)"
        guard
            EditabilityRules.isEditable(
                role: role,
                subrole: subrole,
                valueIsSettable: settable.boolValue,
                hasSelectedRange: selection != nil,
                marksEditable: marksEditable
            )
        else {
            DebugLog.note("REJECTED \(describe)")
            return nil
        }

        let frame = frame(of: element)

        var caret: CGRect?
        var source = "none"
        var atLineEnd = true
        if let selection {
            let index = selection.location + selection.length
            if let c = caretRect(in: element, at: index) {
                caret = c
                source = "range"
                atLineEnd = isLineEnd(in: element, at: index, caret: c)
            }
        }
        // Chromium / WebKit expose the caret through text markers rather than character ranges.
        if caret == nil, let c = markerCaretRect(in: element) {
            caret = c
            source = "marker"
            atLineEnd = false
        }
        // Reject carets that are clearly detached from the field (buggy AX implementations).
        if let c = caret, let f = frame, !f.insetBy(dx: -60, dy: -60).intersects(c) {
            caret = nil
            source = "detached"
        }

        // The caret flickers in and out in some apps; hold the last good one briefly.
        let now = Date()
        if let c = caret {
            lastCaret = (pid, frame, c, atLineEnd, now)
        } else if let held = lastCaret, held.pid == pid, held.frame == frame,
            now.timeIntervalSince(held.time) < 1.5
        {
            caret = held.rect
            atLineEnd = held.atLineEnd
            source = "held"
        }

        var anchor: CGRect
        if let c = caret {
            anchor = c
        } else if let f = frame {
            // No caret anywhere: anchor at the field's leading edge (where text starts) instead
            // of its centre, spanning the field's height so the panel clears the whole field.
            anchor = CGRect(x: f.minX + 10 + Metrics.pillSize.width / 2, y: f.minY, width: 0, height: f.height)
            source = "frame-leading"
        } else {
            DebugLog.note("NO GEOMETRY \(describe)")
            return nil
        }
        let lift = EditabilityRules.isTerminal(bundleID: bundleID) ? PanelPlacement.terminalLift : 0
        DebugLog.note(
            "SHOWN \(describe) caret=\(source) anchor=\(Self.fmt(anchor)) frame=\(frame.map(Self.fmt) ?? "nil") lift=\(lift)"
        )
        return FocusSnapshot(
            caretRect: anchor, elementFrame: frame, isAtLineEnd: atLineEnd, lift: lift,
            appKey: Int(pid), fieldKey: Int(bitPattern: CFHash(element)))
    }

    // MARK: - Element lookup

    private func focusedElement(frontmostPID: pid_t?) -> AXUIElement? {
        if let element = elementValue(systemWide, kAXFocusedUIElementAttribute) { return element }
        guard let pid = frontmostPID, pid != ownPID else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        return elementValue(app, kAXFocusedUIElementAttribute)
    }

    // MARK: - Caret geometry

    private func caretRect(in element: AXUIElement, at index: Int) -> CGRect? {
        if let b = bounds(in: element, CFRange(location: index, length: 0)), isUsable(b) {
            return CGRect(x: b.minX, y: b.minY, width: 0, height: b.height)
        }
        if index > 0, let b = bounds(in: element, CFRange(location: index - 1, length: 1)), isUsable(b) {
            return CGRect(x: b.maxX, y: b.minY, width: 0, height: b.height)
        }
        if let b = bounds(in: element, CFRange(location: index, length: 1)), isUsable(b) {
            return CGRect(x: b.minX, y: b.minY, width: 0, height: b.height)
        }
        return nil
    }

    /// Caret via `AXSelectedTextMarkerRange` + `AXBoundsForTextMarkerRange` (Chromium, WebKit).
    private func markerCaretRect(in element: AXUIElement) -> CGRect? {
        var candidates = [element]
        if let top = elementValue(element, "AXTopLevelUIElement") { candidates.append(top) }
        for target in candidates {
            guard let range = copy(target, "AXSelectedTextMarkerRange") else { continue }
            var result: CFTypeRef?
            guard
                AXUIElementCopyParameterizedAttributeValue(
                    target, "AXBoundsForTextMarkerRange" as CFString, range, &result
                ) == .success, let result, CFGetTypeID(result) == AXValueGetTypeID()
            else { continue }
            var rect = CGRect.zero
            guard AXValueGetValue(result as! AXValue, .cgRect, &rect), isUsable(rect) else { continue }
            return CGRect(x: rect.minX, y: rect.minY, width: 0, height: rect.height)
        }
        return nil
    }

    private func isLineEnd(in element: AXUIElement, at index: Int, caret: CGRect) -> Bool {
        // A caret directly before a line break has nothing after it on its line.
        if let ch = string(in: element, CFRange(location: index, length: 1)),
            ch.contains(where: \.isNewline)
        {
            return true
        }
        guard let next = bounds(in: element, CFRange(location: index, length: 1)), isUsable(next) else {
            return true
        }
        return abs(next.midY - caret.midY) > caret.height * 0.6
    }

    private static func fmt(_ r: CGRect) -> String {
        "(\(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))x\(Int(r.height)))"
    }

    private func isUsable(_ r: CGRect) -> Bool {
        guard r.origin.x.isFinite, r.origin.y.isFinite, r.width.isFinite, r.height.isFinite else { return false }
        if r == .zero { return false }
        return r.height > 0 && r.height < 400
    }

    private func string(in element: AXUIElement, _ range: CFRange) -> String? {
        var range = range
        guard let axRange = AXValueCreate(.cfRange, &range) else { return nil }
        var result: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element, kAXStringForRangeParameterizedAttribute as CFString, axRange, &result
            ) == .success
        else { return nil }
        return result as? String
    }

    private func bounds(in element: AXUIElement, _ range: CFRange) -> CGRect? {
        var range = range
        guard let axRange = AXValueCreate(.cfRange, &range) else { return nil }
        var result: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element, kAXBoundsForRangeParameterizedAttribute as CFString, axRange, &result
            ) == .success, let result, CFGetTypeID(result) == AXValueGetTypeID()
        else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(result as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position = axValue(element, kAXPositionAttribute, .cgPoint, CGPoint.zero),
            let size = axValue(element, kAXSizeAttribute, .cgSize, CGSize.zero),
            size.width > 0, size.height > 0
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func selectedRange(of element: AXUIElement) -> CFRange? {
        axValue(element, kAXSelectedTextRangeAttribute, .cfRange, CFRange(location: 0, length: 0))
    }

    // MARK: - Attribute helpers

    private func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private func stringValue(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }

    private func elementValue(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copy(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func axValue<T>(_ element: AXUIElement, _ attribute: String, _ type: AXValueType, _ zero: T) -> T? {
        guard let value = copy(element, attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var out = zero
        let ok = withUnsafeMutablePointer(to: &out) {
            AXValueGetValue(value as! AXValue, type, UnsafeMutableRawPointer($0))
        }
        return ok ? out : nil
    }
}

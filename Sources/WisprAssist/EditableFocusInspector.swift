import AppKit
import ApplicationServices
import AssistTouchCore

/// What we know about the focused text input. Rects are in Accessibility screen space
/// (origin top-left of the primary display, y grows downward).
struct FocusSnapshot: Equatable {
    var caretRect: CGRect
    var elementFrame: CGRect?
    var isAtLineEnd: Bool
}

/// Reads the focused element through the Accessibility API. Not thread-affine: it is called
/// from a background queue so a hung target app can never block the UI.
final class EditableFocusInspector {
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let systemWide = AXUIElementCreateSystemWide()

    init() {
        // Never wait long on an unresponsive app.
        AXUIElementSetMessagingTimeout(systemWide, 0.25)
    }

    func snapshot(frontmostPID: pid_t?) -> FocusSnapshot? {
        guard let element = focusedElement(frontmostPID: frontmostPID) else { return nil }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid != ownPID else { return nil }

        let role = stringValue(element, kAXRoleAttribute)
        let subrole = stringValue(element, kAXSubroleAttribute)
        let selection = selectedRange(of: element)

        var settable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)

        guard EditabilityRules.isEditable(
            role: role,
            subrole: subrole,
            valueIsSettable: settable.boolValue,
            hasSelectedRange: selection != nil
        ) else { return nil }

        let frame = frame(of: element)

        var caret: CGRect?
        var atLineEnd = true
        if let selection {
            let index = selection.location + selection.length
            caret = caretRect(in: element, at: index)
            if let c = caret {
                atLineEnd = isLineEnd(in: element, at: index, caret: c)
            }
        }
        // Reject carets that are clearly detached from the field (buggy AX implementations).
        if let c = caret, let f = frame, !f.insetBy(dx: -60, dy: -60).intersects(c) {
            caret = nil
        }

        guard let anchor = caret ?? frame else { return nil }
        return FocusSnapshot(caretRect: anchor, elementFrame: frame, isAtLineEnd: caret == nil ? false : atLineEnd)
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

    private func isLineEnd(in element: AXUIElement, at index: Int, caret: CGRect) -> Bool {
        guard let next = bounds(in: element, CFRange(location: index, length: 1)), isUsable(next) else {
            return true
        }
        return abs(next.midY - caret.midY) > caret.height * 0.6
    }

    private func isUsable(_ r: CGRect) -> Bool {
        guard r.origin.x.isFinite, r.origin.y.isFinite, r.width.isFinite, r.height.isFinite else { return false }
        if r == .zero { return false }
        return r.height > 0 && r.height < 400
    }

    private func bounds(in element: AXUIElement, _ range: CFRange) -> CGRect? {
        var range = range
        guard let axRange = AXValueCreate(.cfRange, &range) else { return nil }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString, axRange, &result
        ) == .success, let result, CFGetTypeID(result) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(result as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position = axValue(element, kAXPositionAttribute, .cgPoint, CGPoint.zero),
              let size = axValue(element, kAXSizeAttribute, .cgSize, CGSize.zero),
              size.width > 0, size.height > 0 else { return nil }
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
        guard AXValueGetValue(value as! AXValue, type, &out) else { return nil }
        return out
    }
}

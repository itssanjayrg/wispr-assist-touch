import CoreGraphics

/// Where the panel landed for one focus session. While the user keeps working in the same field
/// the panel keeps this frame instead of chasing the caret, so the buttons stay under their hand
/// while they dictate. Switching app, or moving to a genuinely different field, invalidates it and
/// the panel is placed afresh next to the new caret.
public struct PanelAnchor: Equatable {
    public var appKey: Int
    public var fieldKey: Int
    public var elementFrame: CGRect?
    public var frame: CGRect

    public init(appKey: Int, fieldKey: Int, elementFrame: CGRect?, frame: CGRect) {
        self.appKey = appKey
        self.fieldKey = fieldKey
        self.elementFrame = elementFrame
        self.frame = frame
    }

    /// Still "the same field"? The element identity is the fast path; some apps hand out a new
    /// element object on every query and the field itself grows as text is dictated into it, so a
    /// heavily overlapping frame also counts. A field elsewhere on screen does not.
    public func isValid(appKey: Int, fieldKey: Int, elementFrame: CGRect?) -> Bool {
        guard self.appKey == appKey else { return false }
        if self.fieldKey == fieldKey { return true }
        guard let old = self.elementFrame, let new = elementFrame else { return false }
        return Self.overlapsSubstantially(old, new)
    }

    static func overlapsSubstantially(_ a: CGRect, _ b: CGRect) -> Bool {
        let i = a.intersection(b)
        guard !i.isNull, !i.isEmpty else { return false }
        let smaller = min(a.width * a.height, b.width * b.height)
        guard smaller > 0 else { return false }
        return (i.width * i.height) / smaller >= 0.5
    }
}

import CoreGraphics

/// Where the panel landed for one focus session. While the user keeps working in the same field
/// the panel keeps this frame instead of chasing the caret, so the buttons stay under their hand
/// while they dictate. Switching app, or moving to a genuinely different field, invalidates it and
/// the panel is placed afresh next to the new caret.
public struct PanelAnchor: Equatable {
    public var appKey: Int
    public var fieldKey: Int
    public var elementFrame: CGRect?
    /// The window frame to show the panel at. Starts as the automatic placement and changes only
    /// if the user moves the panel by its handle.
    public var frame: CGRect
    /// The window origin the panel was automatically placed at; limits how far the user may move it.
    public let homeOrigin: CGPoint
    /// Where the caret was when the panel was placed (same coordinate space as `strayed(to:)`'s input).
    public var caret: CGPoint?
    /// True once the user has dragged / nudged the panel; their position is then never overridden.
    public var userMoved = false
    /// How far (points) the caret may travel from its placement point before the panel follows it.
    public static let followDistance: CGFloat = 100

    public init(
        appKey: Int, fieldKey: Int, elementFrame: CGRect?, frame: CGRect, caret: CGPoint? = nil
    ) {
        self.caret = caret
        self.appKey = appKey
        self.fieldKey = fieldKey
        self.elementFrame = elementFrame
        self.frame = frame
        self.homeOrigin = frame.origin
    }

    /// The same session after the user moved the panel. The new position lasts for this session only:
    /// a new field or app (or returning after a pause) builds a fresh anchor at the default position.
    public func moved(to frame: CGRect) -> PanelAnchor {
        var copy = self
        copy.frame = frame
        copy.userMoved = true
        return copy
    }

    /// Has the caret jumped far from where the panel was placed (select-all + delete, clicking
    /// elsewhere in a large editor, ...)? Editors like Obsidian expose one element for the whole
    /// document, so the field never changes and the panel would otherwise be stranded.
    public func strayed(to newCaret: CGPoint) -> Bool {
        guard !userMoved, let old = caret else { return false }
        return hypot(newCaret.x - old.x, newCaret.y - old.y) > Self.followDistance
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

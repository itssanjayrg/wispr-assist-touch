import CoreGraphics

/// Everything the placement algorithm needs to know about the focused text input.
/// All rects use Cocoa screen coordinates (origin bottom-left, y grows upward).
public struct PlacementInput: Equatable {
    /// Insertion point (width is usually 0). Falls back to the element frame when unknown.
    public var caret: CGRect
    /// Frame of the focused text element, when known.
    public var element: CGRect?
    /// `true` when nothing follows the caret on its line (free space to the right).
    public var isAtLineEnd: Bool
    /// Extra distance (points) to push the panel up, for hosts whose caret is drawn over the text
    /// (terminals) so the panel stays clear of it.
    public var lift: CGFloat

    public init(caret: CGRect, element: CGRect? = nil, isAtLineEnd: Bool = true, lift: CGFloat = 0) {
        self.caret = caret
        self.element = element
        self.isAtLineEnd = isAtLineEnd
        self.lift = lift
    }
}

/// Decides where the floating control sits relative to the text cursor.
///
/// Rules:
/// * Single-line fields: above the field/caret, otherwise below. Nothing typed is covered.
/// * Multi-line editors with the caret at the end of a line: beside (trailing) the caret,
///   which is empty space; otherwise above, then below.
/// * The result is always clamped to `bounds` (the screen's visible frame).
public enum PanelPlacement {
    public static let gap: CGFloat = 14
    /// Extra upward offset used for terminal emulators. Together with `gap` the terminal offset
    /// above the cursor is 40 pt (the placement verified as correct in terminals).
    public static let terminalLift: CGFloat = 26
    /// An element taller than this many caret-heights is treated as multi-line.
    static let multilineFactor: CGFloat = 2.2

    enum Side { case above, below, trailing, leading }

    public static func origin(panelSize: CGSize, input: PlacementInput, bounds: CGRect) -> CGPoint {
        let caret = input.caret
        let w = panelSize.width
        let h = panelSize.height

        let isMultiline: Bool = {
            guard let element = input.element, element != caret else { return false }
            return element.height > max(caret.height, 1) * multilineFactor
        }()

        let order: [Side] = (isMultiline && input.isAtLineEnd)
            ? [.trailing, .above, .below, .leading]
            : [.above, .below, .trailing, .leading]

        // Single-line fields: clear the whole field, not just the (shorter) caret rect, so the
        // panel never overlaps the field's own border or padding.
        let top = (!isMultiline ? input.element.map { max(caret.maxY, $0.maxY) } : nil) ?? caret.maxY
        let bottom = (!isMultiline ? input.element.map { min(caret.minY, $0.minY) } : nil) ?? caret.minY

        func frame(for side: Side) -> CGRect {
            switch side {
            case .above:
                return CGRect(x: caret.midX - w / 2, y: top + gap + input.lift, width: w, height: h)
            case .below:
                return CGRect(x: caret.midX - w / 2, y: bottom - gap - h, width: w, height: h)
            case .trailing:
                return CGRect(x: caret.maxX + gap, y: caret.midY - h / 2 + input.lift, width: w, height: h)
            case .leading:
                return CGRect(x: caret.minX - gap - w, y: caret.midY - h / 2, width: w, height: h)
            }
        }

        func fits(_ rect: CGRect, _ side: Side) -> Bool {
            switch side {
            case .above, .below:
                return rect.minY >= bounds.minY && rect.maxY <= bounds.maxY
            case .trailing, .leading:
                return rect.minX >= bounds.minX && rect.maxX <= bounds.maxX
            }
        }

        func clamped(_ rect: CGRect) -> CGPoint {
            let x = max(bounds.minX, min(rect.minX, bounds.maxX - w))
            let y = max(bounds.minY, min(rect.minY, bounds.maxY - h))
            return CGPoint(x: x, y: y)
        }

        for side in order {
            let candidate = frame(for: side)
            if fits(candidate, side) { return clamped(candidate) }
        }
        return clamped(frame(for: order[0]))
    }
}

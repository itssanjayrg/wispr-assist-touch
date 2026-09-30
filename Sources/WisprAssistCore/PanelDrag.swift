import CoreGraphics

/// Rules for the user nudging the panel by its move handle: it may only wander a limited distance
/// from where it first landed ("a little"), and never off the visible part of the screen.
public enum PanelDrag {
    /// Furthest the panel may be moved from its home position, in points.
    public static let maxDistance: CGFloat = 300

    /// - Parameters:
    ///   - origin: where the drag would put the window's bottom-left corner.
    ///   - size: the window size.
    ///   - home: the window origin the panel was automatically placed at.
    ///   - bounds: the area the whole window must stay inside (the screen's visible frame).
    public static func clamp(
        origin: CGPoint, size: CGSize, home: CGPoint, bounds: CGRect, maxDistance: CGFloat = maxDistance
    ) -> CGPoint {
        var x = origin.x
        var y = origin.y

        // Stay within a circle of `maxDistance` around home.
        let dx = x - home.x
        let dy = y - home.y
        let distance = (dx * dx + dy * dy).squareRoot()
        if distance > maxDistance, distance > 0 {
            let scale = maxDistance / distance
            x = home.x + dx * scale
            y = home.y + dy * scale
        }

        // Then keep the whole window on screen (if the bounds are smaller than the window, pin to the edge).
        x = max(bounds.minX, min(x, bounds.maxX - size.width))
        y = max(bounds.minY, min(y, bounds.maxY - size.height))
        return CGPoint(x: x, y: y)
    }
}

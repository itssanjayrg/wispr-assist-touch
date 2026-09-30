import XCTest

@testable import WisprAssistCore

final class PanelDragTests: XCTestCase {
    private let size = CGSize(width: 88, height: 44)
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let home = CGPoint(x: 600, y: 400)

    func testSmallMoveIsUnchanged() {
        let o = PanelDrag.clamp(origin: CGPoint(x: 650, y: 380), size: size, home: home, bounds: screen)
        XCTAssertEqual(o, CGPoint(x: 650, y: 380))
    }

    func testMoveBeyondMaxDistanceIsPulledBackToTheLimit() {
        let o = PanelDrag.clamp(origin: CGPoint(x: 1300, y: 400), size: size, home: home, bounds: screen)
        XCTAssertEqual(o.x, home.x + PanelDrag.maxDistance, accuracy: 0.001)
        XCTAssertEqual(o.y, home.y, accuracy: 0.001)
    }

    func testDiagonalLimitIsACircleNotASquare() {
        let o = PanelDrag.clamp(origin: CGPoint(x: 1000, y: 800), size: size, home: home, bounds: screen)
        let distance = hypot(o.x - home.x, o.y - home.y)
        XCTAssertEqual(distance, PanelDrag.maxDistance, accuracy: 0.001)
    }

    func testStaysOnScreen() {
        let nearEdge = CGPoint(x: 1400, y: 880)
        let o = PanelDrag.clamp(
            origin: CGPoint(x: 1500, y: 950), size: size, home: nearEdge, bounds: screen)
        XCTAssertLessThanOrEqual(o.x + size.width, screen.maxX)
        XCTAssertLessThanOrEqual(o.y + size.height, screen.maxY)
        let low = PanelDrag.clamp(
            origin: CGPoint(x: -50, y: -50), size: size, home: CGPoint(x: 10, y: 10), bounds: screen)
        XCTAssertGreaterThanOrEqual(low.x, screen.minX)
        XCTAssertGreaterThanOrEqual(low.y, screen.minY)
    }
}

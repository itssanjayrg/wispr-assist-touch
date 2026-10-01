import AppKit
import SwiftUI

/// Layout constants. Inner radius 8 + padding 4 = outer radius 12 (concentric corners).
///
/// The window is slightly larger than the visible "pill" so the move handle can hang over the
/// pill's top-left corner. Window coordinates have their origin at the bottom-left.
enum Metrics {
    static let buttonSize = CGSize(width: 36, height: 30)
    static let padding: CGFloat = 4
    static let spacing: CGFloat = 2
    static let outerRadius: CGFloat = 12
    static let innerRadius: CGFloat = 8

    static let handleDiameter: CGFloat = 18
    /// How far the handle sticks out past the pill, to the left and above.
    static let handleOverhang: CGFloat = 6
    /// The handle's centre sits on the pill's rounded corner (outerRadius · (1 − cos 45°) ≈ 3.5 in).
    private static let handleInset: CGFloat = 3.5

    /// The visible rounded rectangle with the buttons.
    static var pillSize: CGSize {
        CGSize(
            width: buttonSize.width * 2 + spacing + padding * 2,
            height: buttonSize.height * 2 + spacing + padding * 2)
    }

    /// The whole window: the pill plus the overhang on its left and top.
    static var windowSize: CGSize {
        CGSize(width: pillSize.width + handleOverhang, height: pillSize.height + handleOverhang)
    }

    static var pillRect: CGRect { CGRect(origin: CGPoint(x: handleOverhang, y: 0), size: pillSize) }

    static var handleCenter: CGPoint {
        CGPoint(x: pillRect.minX + handleInset, y: pillRect.maxY - handleInset)
    }

    /// The Globe button (window coordinates); the Escape row sits above it.
    static var globeButtonRect: CGRect {
        CGRect(origin: CGPoint(x: pillRect.minX + padding, y: padding), size: buttonSize)
    }
}

/// Shared between the panel (which owns the mouse handling) and the view (which draws the handle).
final class HandleState: ObservableObject {
    @Published var isDragging = false
}

struct ControlView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var handleState: HandleState
    @State private var isHoveringPanel = false

    let onGlobeDown: () -> Void
    let onGlobeUp: () -> Void
    let onEscape: () -> Void
    let onClose: () -> Void
    let onDeleteLine: () -> Void
    let onNudge: (CGSize) -> Void

    private var edgeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.85)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: Metrics.spacing) {
                HStack(spacing: Metrics.spacing) {
                    KeyButton(title: "esc", label: "Escape", tooltip: "Escape (esc)", action: onEscape)
                    KeyButton(
                        symbol: "xmark", label: "Close Wispr Assist",
                        tooltip: "Hide Wispr Assist (bring it back from the menu bar icon)",
                        action: onClose, tint: .red)
                }
                HStack(spacing: Metrics.spacing) {
                HoldKeyButton(
                    symbol: "globe", label: "Globe key",
                    tooltip: "Hold to dictate (Globe / fn)  ·  Right-click: Return",
                    onDown: onGlobeDown, onUp: onGlobeUp)
                KeyButton(
                    symbol: "delete.left", label: "Delete line",
                    tooltip: "Delete line (⌘⌫)", action: onDeleteLine)
                }
            }
            .padding(Metrics.padding)
            .frame(width: Metrics.pillSize.width, height: Metrics.pillSize.height)
            .overlay(
                // White edge on the dark theme, dark edge on the light one, so the panel stays
                // visible over any background. Stroked inside the bounds so the window mask can't clip it.
                RoundedRectangle(cornerRadius: Metrics.outerRadius, style: .circular)
                    .strokeBorder(edgeColor, lineWidth: 1)
                    .allowsHitTesting(false)
            )
        }
        .frame(
            width: Metrics.windowSize.width, height: Metrics.windowSize.height,
            alignment: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            MoveHandle(visible: isHoveringPanel || handleState.isDragging, edgeColor: edgeColor, onNudge: onNudge)
                .padding(.leading, Metrics.handleCenter.x - Metrics.handleDiameter / 2)
                .padding(.top, Metrics.windowSize.height - Metrics.handleCenter.y - Metrics.handleDiameter / 2)
        }
        .background(HoverTracker(isHovering: $isHoveringPanel))
    }
}

/// Four-way arrow badge on the pill's top-left corner, revealed on hover. Dragging it is handled by
/// `FloatingPanel.sendEvent`; while hidden it is fully transparent, so clicks there reach the app below.
private struct MoveHandle: View {
    let visible: Bool
    let edgeColor: Color
    let onNudge: (CGSize) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle().fill(colorScheme == .dark ? Color(white: 0.17) : Color(white: 0.97))
            Circle().strokeBorder(edgeColor, lineWidth: 1)
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: Metrics.handleDiameter, height: Metrics.handleDiameter)
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: visible)
        .background(CursorArea(cursor: .openHand))
        .help("Drag to move")
        .accessibilityLabel("Move control")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Move left") { onNudge(CGSize(width: -10, height: 0)) }
        .accessibilityAction(named: "Move right") { onNudge(CGSize(width: 10, height: 0)) }
        .accessibilityAction(named: "Move up") { onNudge(CGSize(width: 0, height: 10)) }
        .accessibilityAction(named: "Move down") { onNudge(CGSize(width: 0, height: -10)) }
    }
}

/// Shows `cursor` over the view even though the panel is never the key window.
private struct CursorArea: NSViewRepresentable {
    let cursor: NSCursor

    func makeNSView(context: Context) -> CursorView {
        let view = CursorView()
        view.cursor = cursor
        return view
    }

    func updateNSView(_ view: CursorView, context: Context) { view.cursor = cursor }

    final class CursorView: NSView {
        var cursor: NSCursor = .arrow

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(
                NSTrackingArea(
                    rect: .zero, options: [.cursorUpdate, .activeAlways, .inVisibleRect],
                    owner: self, userInfo: nil))
        }

        override func cursorUpdate(with event: NSEvent) { cursor.set() }
    }
}

private struct KeyButton: View {
    var symbol: String?
    var title: String?
    let label: String
    let tooltip: String
    let action: () -> Void
    var tint: Color?

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let symbol {
                    Image(systemName: symbol).symbolRenderingMode(.monochrome)
                } else if let title {
                    Text(title)
                }
            }
            .font(.system(size: 14, weight: .medium))
            .frame(width: Metrics.buttonSize.width, height: Metrics.buttonSize.height)
        }
        .buttonStyle(KeyButtonStyle(isHovering: isHovering, tint: tint))
        .background(HoverTracker(isHovering: $isHovering))
        .help(tooltip)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

/// Acts like a physical key: `onDown` fires the moment the mouse goes down and `onUp` when it is
/// released (even if the pointer has moved off the button), so holding the button holds the key.
private struct HoldKeyButton: View {
    let symbol: String
    let label: String
    let tooltip: String
    let onDown: () -> Void
    let onUp: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .medium))
            .symbolRenderingMode(.monochrome)
            .frame(width: Metrics.buttonSize.width, height: Metrics.buttonSize.height)
            .foregroundStyle(.primary)
            .background(shape.fill(Color.primary.opacity(isPressed ? 0.18 : (isHovering ? 0.09 : 0))))
            .contentShape(shape)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onDown()
                    }
                    .onEnded { _ in
                        isPressed = false
                        onUp()
                    }
            )
            .background(HoverTracker(isHovering: $isHovering))
            .onDisappear { if isPressed { isPressed = false; onUp() } }
            .help(tooltip)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Press Return") { KeyEventPoster.pressReturn() }
            .accessibilityAction {
                // VoiceOver / Switch Control "press": a short hold.
                onDown()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onUp() }
            }
    }
}

private struct KeyButtonStyle: ButtonStyle {
    let isHovering: Bool
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        configuration.label
            .foregroundStyle(tint ?? .primary)
            .background(shape.fill((tint ?? .primary).opacity(configuration.isPressed ? 0.18 : (isHovering ? 0.09 : 0))))
            .contentShape(shape)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

/// SwiftUI's `onHover` only fires for key windows; the panel never becomes key, so hover is
/// tracked with an `.activeAlways` tracking area instead.
private struct HoverTracker: NSViewRepresentable {
    @Binding var isHovering: Bool

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onChange = { hovering in DispatchQueue.main.async { isHovering = hovering } }
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {
        view.onChange = { hovering in DispatchQueue.main.async { isHovering = hovering } }
    }

    final class TrackingView: NSView {
        var onChange: ((Bool) -> Void)?
        private var occlusionToken: NSObjectProtocol?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(
                NSTrackingArea(
                    rect: .zero,
                    options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                    owner: self, userInfo: nil))
        }

        override func mouseEntered(with event: NSEvent) { onChange?(true) }
        override func mouseExited(with event: NSEvent) { onChange?(false) }

        // Hiding the panel while hovered produces no mouseExited; reset when it goes away.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token = occlusionToken { NotificationCenter.default.removeObserver(token) }
            occlusionToken = nil
            guard let window else { return }
            occlusionToken = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in
                if !window.occlusionState.contains(.visible) { self?.onChange?(false) }
            }
        }

        deinit {
            if let token = occlusionToken { NotificationCenter.default.removeObserver(token) }
        }
    }
}

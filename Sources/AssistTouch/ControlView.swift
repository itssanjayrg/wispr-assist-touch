import AppKit
import SwiftUI

/// Layout constants. Inner radius 8 + padding 4 = outer radius 12 (concentric corners).
enum Metrics {
    static let buttonSize = CGSize(width: 36, height: 30)
    static let padding: CGFloat = 4
    static let spacing: CGFloat = 2
    static let outerRadius: CGFloat = 12
    static let innerRadius: CGFloat = 8

    static var panelSize: CGSize {
        CGSize(width: buttonSize.width * 2 + spacing + padding * 2,
               height: buttonSize.height + padding * 2)
    }
}

struct ControlView: View {
    let onGlobe: () -> Void
    let onReturn: () -> Void

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            KeyButton(symbol: "globe", label: "Globe key",
                      tooltip: "Globe (fn)", action: onGlobe)
            KeyButton(symbol: "return", label: "Return key",
                      tooltip: "Return", action: onReturn)
        }
        .padding(Metrics.padding)
        .frame(width: Metrics.panelSize.width, height: Metrics.panelSize.height)
    }
}

private struct KeyButton: View {
    let symbol: String
    let label: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .frame(width: Metrics.buttonSize.width, height: Metrics.buttonSize.height)
        }
        .buttonStyle(KeyButtonStyle(isHovering: isHovering))
        .background(HoverTracker(isHovering: $isHovering))
        .help(tooltip)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

private struct KeyButtonStyle: ButtonStyle {
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        configuration.label
            .foregroundStyle(.primary)
            .background(shape.fill(Color.primary.opacity(configuration.isPressed ? 0.18 : (isHovering ? 0.09 : 0))))
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
            addTrackingArea(NSTrackingArea(
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

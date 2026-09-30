# Architecture

Wispr Assist is a menu-bar (`LSUIElement`) app. It watches which text field is focused, floats a small
panel beside the caret, and turns button presses into synthetic key events.

```
            ┌────────────────────────────── WisprAssist (app target) ──────────────────────────────┐
 focus      │ FocusTracker ──▶ EditableFocusInspector ──▶ FocusSnapshot ──▶ PanelController ──▶ FloatingPanel
 changes ──▶│  (AXObserver +     (Accessibility reads,        (caret, field        (placement, anchor,    (non-activating
            │   0.25 s poll)      background queue)            frame, key)           show/move/hide)        NSPanel + SwiftUI)
            │                                                                                              │
            │                                                          button events ──▶ KeyEventPoster ──▶ CGEvent (HID tap)
            └──────────────────────────────────────────────────────────────────────────────────────────────┘
                     uses pure, unit-tested logic from ▶ WisprAssistCore:
                     EditabilityRules · PanelPlacement · PanelAnchor · PanelDrag
```

## Modules

**`WisprAssistCore`** — no AppKit, no Accessibility, fully unit tested.
- `EditabilityRules`: from a few Accessibility attributes, decides whether a focused element is an
  editable text input (and never a secure/password field). Also identifies terminal apps.
- `PanelPlacement`: given the caret, the field frame and the screen, computes where the panel goes
  (above / below / beside the caret, clamped to the visible screen area).
- `PanelDrag`: limits how far and where the user may move the panel by its handle.
- `PanelAnchor`: remembers where the panel landed for the current field and decides whether a new
  snapshot is still "the same field" (so the panel doesn't chase the caret).

**`WisprAssist`** — everything that touches the OS.
- `AppDelegate`: status item, menu, reacting to the Accessibility permission changing.
- `FocusTracker`: attaches an `AXObserver` to the frontmost app, coalesces notifications, and polls as a
  safety net (faster while the panel is visible). All reads run on a background queue so a hung target
  app can never block the UI; results are applied on the main thread with a generation counter so stale
  reads are dropped.
- `EditableFocusInspector`: reads role, subrole, value-settable, selection and geometry. Finds the
  caret through `AXBoundsForRange`, then text markers (Chromium/WebKit), then the field's leading edge.
- `PanelController`: converts Accessibility coordinates (top-left origin) to Cocoa, applies the anchor,
  animates, and debounces hiding so tabbing between fields doesn't flicker.
- `FloatingPanel` / `ControlView`: a borderless **non-activating** panel that can never become key, so
  the text field keeps keyboard focus. Right-clicks are handled in `sendEvent` because SwiftUI has no
  right-click gesture for a panel that is never key.
- Move handle: the window is slightly larger than the visible pill so a hover-revealed ✥ badge can hang
  over its top-left corner (transparent elsewhere, so clicks pass through). `FloatingPanel.sendEvent`
  tracks the drag; `PanelController` clamps it with `PanelDrag` (≤ 300 pt from the automatic position,
  on screen) and stores the result in the session's `PanelAnchor`, which is discarded on a new field/app.
- `KeyEventPoster`: posts Fn (held while the Globe button is held), Return and ⌘⌫ through the HID tap.
  Fn state lives on one serial queue so an "up" is never sent without a "down".

## Key decisions
- **Non-activating panel.** Clicking it must not steal focus from the field being typed into.
- **Background Accessibility reads + coalescing.** Accessibility IPC can block on a slow app.
- **Holding, not tapping, the Globe key.** Dictation tools trigger on press-and-hold.
- **Pure core module.** Placement and editability rules change often and are the easiest things to get
  subtly wrong; they're testable without a display or permission.
- **No network, no text access.** See `SECURITY.md`.

## Testing
`swift test` covers `WisprAssistCore`. The Accessibility and windowing layers are verified by hand and
through the opt-in diagnostic log (see README ▸ Troubleshooting). Putting the Accessibility layer behind
a protocol so it can be tested with fakes is a good first contribution.

import AppKit
import ApplicationServices

/// Watches the frontmost app for focus / caret changes and reports a `FocusSnapshot?`.
///
/// Event driven (AXObserver) with a light polling safety net for apps that do not post every
/// notification. All heavy Accessibility reads happen on a background queue and are coalesced,
/// so typing is never slowed down.
final class FocusTracker {
    private let onChange: (FocusSnapshot?) -> Void
    private let inspector = EditableFocusInspector()
    private let queue = DispatchQueue(label: "app.wisprassist.ax", qos: .userInteractive)
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    private var running = false
    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var pollTimer: Timer?
    private var workspaceTokens: [NSObjectProtocol] = []

    private var refreshScheduled = false
    private var inFlight = false
    private var needsRerun = false
    private var generation = 0
    private var last: FocusSnapshot?
    private var pollTick = 0
    private var manualAXPIDs = Set<pid_t>()

    private static let notifications: [String] = [
        kAXFocusedUIElementChangedNotification,
        kAXSelectedTextChangedNotification,
        kAXValueChangedNotification,
        kAXFocusedWindowChangedNotification,
        kAXMainWindowChangedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
        kAXMovedNotification,
        kAXResizedNotification
    ]

    init(onChange: @escaping (FocusSnapshot?) -> Void) {
        self.onChange = onChange
    }

    deinit { stop() }

    // MARK: - Lifecycle (main thread)

    func start() {
        guard !running else { return }
        running = true

        let center = NSWorkspace.shared.notificationCenter
        workspaceTokens.append(
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
            ) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                self?.attach(to: app)
                self?.scheduleRefresh()
            })
        for name in [
            NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        ] {
            workspaceTokens.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    self?.scheduleRefresh()
                })
        }

        attach(to: NSWorkspace.shared.frontmostApplication)

        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.handlePoll() }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        scheduleRefresh()
    }

    /// Notifications drive updates; the poll is only a safety net. While nothing is shown it
    /// runs at a quarter of the rate so an idle Mac isn't hammered with Accessibility IPC.
    private func handlePoll() {
        pollTick &+= 1
        if last != nil || pollTick % 4 == 0 { scheduleRefresh() }
    }

    func stop() {
        guard running else { return }
        running = false
        pollTimer?.invalidate()
        pollTimer = nil
        let center = NSWorkspace.shared.notificationCenter
        workspaceTokens.forEach(center.removeObserver)
        workspaceTokens.removeAll()
        detach()
        generation += 1
        last = nil
    }

    // MARK: - AXObserver

    private func attach(to app: NSRunningApplication?) {
        guard let app, app.processIdentifier != ownPID else { return }
        let pid = app.processIdentifier
        guard pid != observedPID || observer == nil else { return }
        detach()

        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.25)

        // Chromium / Electron only build their accessibility tree on request. Doing this for
        // other apps is pointless, so limit it (and do it once per process).
        if Self.isChromiumBased(app), manualAXPIDs.insert(pid).inserted {
            queue.async {
                AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
                AXUIElementSetAttributeValue(element, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            }
        }

        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            Unmanaged<FocusTracker>.fromOpaque(refcon).takeUnretainedValue().scheduleRefresh()
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.notifications {
            AXObserverAddNotification(created, element, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        observedPID = pid
    }

    private static func isChromiumBased(_ app: NSRunningApplication) -> Bool {
        if let url = app.bundleURL {
            let frameworks = url.appendingPathComponent("Contents/Frameworks")
            // Electron forks rename the framework (e.g. "Codex Framework"), but every Chromium
            // host ships "<Name> Helper (Renderer).app".
            let entries = (try? FileManager.default.contentsOfDirectory(atPath: frameworks.path)) ?? []
            if entries.contains(where: {
                $0.hasSuffix("Helper (Renderer).app") || $0 == "Electron Framework.framework"
                    || $0 == "Chromium Embedded Framework.framework"
            }) {
                return true
            }
        }
        let id = (app.bundleIdentifier ?? "").lowercased()
        return [
            "com.google.chrome", "org.chromium", "com.brave", "com.microsoft.edgemac",
            "com.vivaldi", "company.thebrowser", "com.operasoftware"
        ].contains { id.hasPrefix($0) }
    }

    private func detach() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedPID = 0
    }

    // MARK: - Coalesced refresh

    private func scheduleRefresh() {
        guard running, !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) { [weak self] in
            self?.refreshScheduled = false
            self?.performRefresh()
        }
    }

    private func performRefresh() {
        guard running else { return }
        if inFlight { needsRerun = true; return }
        inFlight = true
        generation += 1
        let token = generation
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier

        queue.async { [inspector] in
            let snapshot = inspector.snapshot(frontmostPID: pid)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.inFlight = false
                if self.running, token == self.generation, snapshot != self.last {
                    self.last = snapshot
                    self.onChange(snapshot)
                }
                if self.needsRerun {
                    self.needsRerun = false
                    self.scheduleRefresh()
                }
            }
        }
    }
}

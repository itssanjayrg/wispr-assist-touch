import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let panelController = PanelController()
    private lazy var tracker = FocusTracker { [weak self] snapshot in
        self?.panelController.update(snapshot)
    }

    private var statusItem: NSStatusItem?
    private var enabledItem: NSMenuItem?
    private var accessItem: NSMenuItem?
    private var loginItem: NSMenuItem?
    private var trustTimer: Timer?
    private var trustObserver: NSObjectProtocol?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        LaunchAtLogin.configureOnLaunch()
        buildStatusItem()

        if !AccessibilityPermission.isTrusted { AccessibilityPermission.prompt() }

        // React instantly to the user flipping the switch in System Settings…
        trustObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.reconcile() }
        }
        // …and keep a cheap poll as a safety net (also catches revocation).
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.reconcile() }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        trustTimer = timer

        reconcile()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tracker.stop()
        panelController.hideNow()
    }

    /// Single place that makes reality match (permission × user setting).
    private func reconcile() {
        let trusted = AccessibilityPermission.isTrusted
        if trusted && Settings.isEnabled {
            tracker.start()
        } else {
            tracker.stop()
            panelController.hideNow()
            DebugLog.note("tracking off (trusted=\(trusted), enabled=\(Settings.isEnabled)): panel hidden")
        }
        updateStatusIcon(trusted: trusted)
    }

    // MARK: - Status item

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.toolTip = "Wispr Assist"
        statusItem = item

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let header = NSMenuItem(title: "Wispr Assist", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let enabled = NSMenuItem(title: "Show Floating Control", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.target = self
        menu.addItem(enabled)
        enabledItem = enabled

        let access = NSMenuItem(title: "", action: #selector(openAccessibility), keyEquivalent: "")
        access.target = self
        menu.addItem(access)
        accessItem = access

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        menu.addItem(login)
        loginItem = login

        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quit Wispr Assist", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        item.menu = menu
        updateStatusIcon(trusted: AccessibilityPermission.isTrusted)
    }

    private func updateStatusIcon(trusted: Bool) {
        let name = trusted ? "waveform" : "exclamationmark.triangle"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Wispr Assist")
        image?.isTemplate = true
        statusItem?.button?.image = image
        statusItem?.button?.appearsDisabled = trusted && !Settings.isEnabled
    }

    func menuWillOpen(_ menu: NSMenu) {
        let trusted = AccessibilityPermission.isTrusted
        enabledItem?.state = Settings.isEnabled ? .on : .off
        enabledItem?.isEnabled = trusted
        accessItem?.title = trusted ? "Accessibility Access Granted" : "Grant Accessibility Access…"
        accessItem?.state = trusted ? .on : .off
        loginItem?.title = LaunchAtLogin.needsApproval ? "Open at Login (allow in System Settings…)" : "Open at Login"
        loginItem?.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        Settings.isEnabled.toggle()
        reconcile()
    }

    @objc private func openAccessibility() {
        // The launch-time prompt already registered the app in the Accessibility list, so
        // opening Settings alone is enough (prompting as well would show two dialogs).
        AccessibilityPermission.openSystemSettings()
    }

    @objc private func toggleLogin() {
        if LaunchAtLogin.needsApproval {
            SMAppService.openSystemSettingsLoginItems()
        } else {
            LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
        }
    }
}

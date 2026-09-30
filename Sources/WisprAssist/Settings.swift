import Foundation
import ServiceManagement

enum Settings {
    private static let enabledKey = "isEnabled"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [enabledKey: true])
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}

enum LaunchAtLogin {
    private static let configuredKey = "loginItemConfigured"

    static var status: SMAppService.Status { SMAppService.mainApp.status }

    /// `true` when the app will start at login. `requiresApproval` means macOS registered it but
    /// the user still has to allow it under System Settings ▸ General ▸ Login Items.
    static var isEnabled: Bool { status == .enabled }
    static var needsApproval: Bool { status == .requiresApproval }

    /// Turns launch-at-login on the first time the app ever runs, so it works out of the box.
    /// After that the user's choice from the menu is respected. If the registration has gone
    /// missing (e.g. the app bundle was rebuilt or moved) while the user still wants it, repair it.
    static func configureOnLaunch() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: configuredKey) {
            defaults.set(true, forKey: configuredKey)
            defaults.set(true, forKey: wantedKey)
            set(true)
        } else if defaults.bool(forKey: wantedKey), status == .notRegistered || status == .notFound {
            set(true)
        }
    }

    private static let wantedKey = "loginItemWanted"

    static func set(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: wantedKey)
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("WisprAssist: launch-at-login change failed: \(error.localizedDescription)")
        }
        if enabled, needsApproval { SMAppService.openSystemSettingsLoginItems() }
    }
}

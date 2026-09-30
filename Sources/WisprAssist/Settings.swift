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
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("WisprAssist: launch-at-login change failed: \(error.localizedDescription)")
        }
    }
}

import Foundation

/// Tiny local-only diagnostic log (~/Library/Logs/WisprAssist.log) of *why* the control was or
/// was not shown for the focused element: bundle id, role, flags. Never records typed text.
/// Consecutive identical lines are collapsed, so it only grows when something changes.
///
/// Off by default. Enable it when reporting a compatibility problem:
///     defaults write app.wisprassist.WisprAssist debugLogging -bool true
/// and restart the app. Disable with `defaults delete app.wisprassist.WisprAssist debugLogging`.
enum DebugLog {
    private static let queue = DispatchQueue(label: "app.wisprassist.log")
    private static var lastLine = ""
    private static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/WisprAssist.log")

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: "debugLogging") }

    static func note(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let message = message()
        queue.async {
            guard message != lastLine else { return }
            lastLine = message
            let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }
}

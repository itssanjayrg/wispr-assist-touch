import Foundation

/// Tiny local-only diagnostic log (~/Library/Logs/WisprAssist.log) of *why* the control was or
/// was not shown for the focused element: bundle id, role, flags. Never records typed text.
/// Consecutive identical lines are collapsed, so it only grows when something changes.
enum DebugLog {
    private static let queue = DispatchQueue(label: "app.wisprassist.log")
    private static var lastLine = ""
    private static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/WisprAssist.log")

    static func note(_ message: String) {
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

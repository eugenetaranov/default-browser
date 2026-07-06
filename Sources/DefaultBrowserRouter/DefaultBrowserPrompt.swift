import AppKit

/// Helpers for checking and requesting default-browser status.
enum DefaultBrowserPrompt {
    /// Whether this app is currently the system default handler for web links.
    static var isCurrentDefault: Bool {
        guard let probe = URL(string: "https://example.com"),
              let current = NSWorkspace.shared.urlForApplication(toOpen: probe)
        else { return false }
        return current.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
    }

    /// Ask macOS to make this app the default http/https handler. On modern macOS this
    /// surfaces a system confirmation dialog, giving the user an actionable first-run step.
    static func requestDefault() {
        let bundleID = (Bundle.main.bundleIdentifier ?? "") as CFString
        for scheme in ["http", "https"] {
            let status = LSSetDefaultHandlerForURLScheme(scheme as CFString, bundleID)
            log("Requested default handler for \(scheme) (status \(status))")
        }
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data(("[default-browser-router] " + message + "\n").utf8))
    }
}

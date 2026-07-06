import AppKit

/// Thin wrapper over NSWorkspace for installation checks and launching URLs
/// in a specific browser addressed by bundle id.
enum BrowserLauncher {
    static func appURL(bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func isInstalled(bundleID: String) -> Bool {
        appURL(bundleID: bundleID) != nil
    }

    /// Open the original, unmodified URL in the app with the given bundle id.
    static func open(_ url: URL, bundleID: String, completion: @escaping (Bool) -> Void) {
        guard let app = appURL(bundleID: bundleID) else {
            completion(false)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: config) { _, error in
            DispatchQueue.main.async { completion(error == nil) }
        }
    }
}

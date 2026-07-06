import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` for "Open at Login" registration.
///
/// Note: registration only takes effect for a codesigned app in a stable location
/// (e.g. /Applications). See README.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register the app to launch at login. Returns false (and logs) on failure.
    @discardableResult
    static func enable() -> Bool {
        do {
            try SMAppService.mainApp.register()
            return true
        } catch {
            log("Failed to enable Open at Login: \(error)")
            return false
        }
    }

    /// Unregister the login item. Returns false (and logs) on failure.
    @discardableResult
    static func disable() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            return true
        } catch {
            log("Failed to disable Open at Login: \(error)")
            return false
        }
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data(("[default-browser-router] " + message + "\n").utf8))
    }
}

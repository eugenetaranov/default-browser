import Foundation

/// Resolves a `browser` config value (friendly name or bundle id) into a bundle id.
public enum BrowserResolver {
    /// Friendly name (lowercased) -> bundle identifier.
    public static let nameToBundleID: [String: String] = [
        "safari": "com.apple.Safari",
        "firefox": "org.mozilla.firefox",
        "firefox developer edition": "org.mozilla.firefoxdeveloperedition",
        "brave": "com.brave.Browser",
        "chrome": "com.google.Chrome",
        "google chrome": "com.google.Chrome",
        "chrome canary": "com.google.Chrome.canary",
        "chromium": "org.chromium.Chromium",
        "edge": "com.microsoft.edgemac",
        "microsoft edge": "com.microsoft.edgemac",
        "arc": "company.thebrowser.Browser",
        "opera": "com.operasoftware.Opera",
        "vivaldi": "com.vivaldi.Vivaldi",
        "orion": "com.kagi.kagimacOS",
        "zen": "app.zen-browser.zen",
        "duckduckgo": "com.duckduckgo.macos.browser",
    ]

    /// Bundle id of Safari — the guaranteed-present final fallback on macOS.
    public static let safariBundleID = "com.apple.Safari"

    /// Resolve a config value to a bundle id.
    /// A value containing a dot is treated as a bundle id verbatim; otherwise it is
    /// looked up (case-insensitively) in the friendly-name map. Returns nil if unknown.
    public static func bundleID(for value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains(".") {
            return trimmed
        }
        return nameToBundleID[trimmed.lowercased()]
    }
}

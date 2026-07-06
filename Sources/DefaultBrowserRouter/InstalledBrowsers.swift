import AppKit
import RouterCore

/// Lists installed browsers (by friendly name) for the rule-editor pickers.
enum InstalledBrowsers {
    /// Friendly names from the known map that are actually installed, sorted.
    static func names() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        // Preserve nicer display names; the map has lowercased keys.
        let display: [String: String] = [
            "safari": "Safari", "firefox": "Firefox", "brave": "Brave",
            "chrome": "Chrome", "chromium": "Chromium", "edge": "Edge",
            "arc": "Arc", "opera": "Opera", "vivaldi": "Vivaldi",
            "orion": "Orion", "zen": "Zen", "duckduckgo": "DuckDuckGo",
        ]
        for (name, bundleID) in BrowserResolver.nameToBundleID.sorted(by: { $0.key < $1.key }) {
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil else { continue }
            let label = display[name] ?? name.capitalized
            if seen.insert(label).inserted { result.append(label) }
        }
        return result.sorted()
    }
}

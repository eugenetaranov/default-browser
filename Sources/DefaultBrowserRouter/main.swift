import AppKit
import RouterCore

// CLI helper: `DefaultBrowserRouter --set-default` asks macOS to make this app the
// default handler for http/https (prompts the user to confirm), then exits.
if CommandLine.arguments.contains("--set-default") {
    DefaultBrowserPrompt.requestDefault()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Agent app: no Dock icon, no menu bar. Reinforces LSUIElement from Info.plist.
app.setActivationPolicy(.accessory)
app.run()

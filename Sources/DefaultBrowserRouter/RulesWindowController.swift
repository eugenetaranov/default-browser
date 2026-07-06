import AppKit
import SwiftUI

/// Hosts the SwiftUI rules editor in a window. Because the app is a headless `.accessory`
/// agent, we temporarily switch to `.regular` while the window is open so it can take focus,
/// then back to `.accessory` on close.
final class RulesWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model = RulesViewModel()

    func show() {
        model.load()

        if window == nil {
            let hosting = NSHostingController(rootView: RulesEditorView(model: model))
            let win = NSWindow(contentViewController: hosting)
            win.title = "Rules — Default Browser Router"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.setContentSize(NSSize(width: 620, height: 480))
            win.center()
            window = win
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Return to headless agent mode once the editor is dismissed.
        NSApp.setActivationPolicy(.accessory)
    }
}

import AppKit

/// Owns the menu bar status item and its menu (About, Open at Login, Quit).
/// Its presence is the "the router is running" indicator.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        // Monochrome chain-link glyph; template image auto-adapts to light/dark menu bar.
        let image = NSImage(systemSymbolName: "link", accessibilityDescription: "Default Browser Router")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Default Browser Router"

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    /// Rebuilt on open so the "Open at Login" checkmark reflects current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        let header = NSMenuItem(title: "Default Browser Router", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(NSMenuItem(
            title: "About Default Browser Router",
            action: #selector(showAbout),
            keyEquivalent: ""
        ).targeted(self))

        let loginItem = NSMenuItem(
            title: "Open at Login",
            action: #selector(toggleLogin),
            keyEquivalent: ""
        ).targeted(self)
        loginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }

    @objc private func showAbout() {
        // Accessory apps aren't active by default; activate so the panel comes forward.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func toggleLogin() {
        if LoginItem.isEnabled {
            LoginItem.disable()
        } else {
            LoginItem.enable()
        }
        rebuildMenu()
    }
}

private extension NSMenuItem {
    /// Convenience to set the target inline while building the menu.
    func targeted(_ target: AnyObject) -> NSMenuItem {
        self.target = target
        return self
    }
}

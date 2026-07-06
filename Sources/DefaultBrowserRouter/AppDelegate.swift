import AppKit
import RouterCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ConfigStore()
    private var statusItemController: StatusItemController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register the GetURL Apple Event handler as early as possible so URLs that
        // triggered our launch are delivered to us.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        // Ensure the config file exists on first run.
        _ = try? store.createIfMissing()
    }

    private static let firstRunKey = "didCompleteFirstRun"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Install the main menu so standard editing shortcuts (Cmd+A/C/V/X/Z) reach text
        // fields in our windows. Without an Edit menu, AppKit never dispatches these.
        MainMenu.install()
        // Show the menu bar indicator; the app now stays resident until Quit.
        statusItemController = StatusItemController()
        // Launch-at-login: register once so the indicator is present from startup.
        if !LoginItem.isEnabled {
            LoginItem.enable()
        }
        runFirstLaunchOnboardingIfNeeded()
    }

    /// On the very first launch, guide the user to make us the default browser. A headless
    /// app otherwise shows no feedback, so we surface the system "set default browser" prompt.
    private func runFirstLaunchOnboardingIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.firstRunKey) else { return }
        defaults.set(true, forKey: Self.firstRunKey)

        if !DefaultBrowserPrompt.isCurrentDefault {
            NSApp.activate(ignoringOtherApps: true)
            DefaultBrowserPrompt.requestDefault()
        }
    }

    /// Apple Event path: the primary way macOS delivers opened http/https URLs.
    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor,
                                         withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string) else { return }
        route(url, source: Self.sourceApplication(from: event))
    }

    /// AppKit also delivers opened files/URLs here; handle multiple independently.
    func application(_ application: NSApplication, open urls: [URL]) {
        let source = NSWorkspace.shared.frontmostApplication
        for url in urls { route(url, source: source) }
    }

    /// The app that sent the GetURL event, via its sender PID (`keySenderPIDAttr` = 'spid'),
    /// falling back to the frontmost application.
    private static func sourceApplication(from event: NSAppleEventDescriptor) -> NSRunningApplication? {
        let keySenderPIDAttr = AEKeyword(0x73706964) // 'spid'
        if let pidDesc = event.attributeDescriptor(forKeyword: keySenderPIDAttr) {
            let pid = pidDesc.int32Value
            if pid > 0, let app = NSRunningApplication(processIdentifier: pid) {
                return app
            }
        }
        return NSWorkspace.shared.frontmostApplication
    }

    // MARK: - Routing

    private func route(_ url: URL, source: NSRunningApplication?) {
        let context = RequestContext(
            url: url,
            sourceAppName: source?.localizedName,
            sourceBundleID: source?.bundleIdentifier
        )
        route(context)
    }

    private func route(_ context: RequestContext) {
        let url = context.url
        // Reload config on every event so edits apply without restarting. Fail safe.
        let config: Config
        do {
            config = try store.load()
        } catch {
            log("Config error: \(error). Falling back to Safari.")
            openInSafari(url)
            return
        }

        let router = Router(
            config: config,
            selfBundleID: Bundle.main.bundleIdentifier,
            isInstalled: { BrowserLauncher.isInstalled(bundleID: $0) }
        )

        guard let target = router.resolveTargetBundleID(for: context) else {
            log("No installable target for \(url.absoluteString); using Safari.")
            openInSafari(url)
            return
        }
        open(url, inBundleID: target)
    }

    private func open(_ url: URL, inBundleID bundleID: String) {
        BrowserLauncher.open(url, bundleID: bundleID) { [weak self] ok in
            if !ok {
                self?.log("Launch failed for \(bundleID); using Safari.")
                self?.openInSafari(url)
            }
        }
    }

    private func openInSafari(_ url: URL) {
        BrowserLauncher.open(url, bundleID: BrowserResolver.safariBundleID) { _ in }
    }

    private func log(_ message: String) {
        FileHandle.standardError.write(Data(("[default-browser-router] " + message + "\n").utf8))
    }
}

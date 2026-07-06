## Context

macOS routes every clicked `http`/`https` link to the single app registered as the default web browser via LaunchServices. To insert per-URL routing, our app must itself be a valid, selectable default browser: a codesigned `.app` bundle that declares `http`/`https` URL schemes and receives Apple Events / `application(_:open:)` callbacks. It then re-launches each URL in a target browser chosen by config.

This is a greenfield single-purpose macOS app. There is no existing code, no server, and no persistent state beyond the user's YAML config file. The app has no UI surface (no window, no Dock icon, no menu bar item) — it is effectively an invisible router.

## Goals / Non-Goals

**Goals:**
- Be a legitimately selectable macOS default browser.
- Route each opened URL to a browser chosen by ordered domain/prefix rules with a catch-all default.
- Keep configuration a single, human-editable YAML file that takes effect without rebuilding.
- Never lose a URL: any error path falls back to launching the default browser.
- Stay minimal and native (Swift/AppKit), background-only.

**Non-Goals:**
- No preferences window or GUI config editor (a minimal menu bar item with About / Open at Login / Quit is now in scope; full settings UI is not).
- No regex or wildcard globbing beyond domain-suffix and URL-prefix matching (can come later).
- No per-profile / per-window browser targeting, no incognito flags (future extension).
- No auto-update mechanism, telemetry, or analytics.
- Not distributed via the App Store (sandbox restricts default-browser registration and launching arbitrary apps).

## Decisions

### Language & framework: Swift + AppKit, built as an `.app` bundle
Native, first-class access to `NSWorkspace`, `LaunchServices`, and URL Apple Events. AppKit is required (not pure SwiftPM executable) because default-browser registration needs a real bundle with `Info.plist`. Build via an Xcode project or SwiftPM with a bundling step; recommend Xcode project for reliable codesigning + `Info.plist` control.
- *Alternative considered:* Electron/Tauri — rejected as heavyweight for a headless router. A shell script wrapper — rejected because it can't register as a default browser.

### Receiving URLs: `NSApplicationDelegate.application(_:open:)` + `kAEGetURL` Apple Event
Register a handler for the `GetURL` Apple Event and/or implement `application(_:open:)`. AppKit delivers the opened URLs there. Handle multiple URLs per event.

### Headless operation: `LSUIElement = true`
Set `LSUIElement` so the app has no Dock icon. It runs as an `.accessory` app, which still permits a menu bar status item (see below).

### Menu bar status item + resident lifecycle
The app shows an `NSStatusItem` (monochrome SF Symbol `link`, template image) as a running indicator, with a menu of About / Open at Login / Quit. Because the icon must persist, the app **stays resident** until Quit rather than auto-terminating after each link. "Open at Login" is backed by `SMAppService.mainApp` (macOS 13+), registered on first launch so the indicator is present from startup.
- *Alternative considered:* auto-terminate after an idle window (original design) — rejected because a persistent running indicator requires residency. *Alternative for login item:* legacy `SMLoginItemSetEnabled` helper (supports macOS 12) — rejected as more moving parts; raising the minimum to macOS 13 is acceptable.

### Launching target browsers: `NSWorkspace.open(_:withApplicationAt:configuration:)`
Resolve a browser by bundle identifier (preferred, stable) or by app name → bundle URL via `LSCopyApplicationURLsForBundleIdentifier` / `NSWorkspace.urlForApplication(withBundleIdentifier:)`. Launch the original URL in that app. Using bundle IDs avoids ambiguity and localized app names.
- *Alternative considered:* shelling out to `/usr/bin/open -b <bundleid> <url>` — works but adds a process hop and weaker error handling; keep as fallback only.

### Config format & location: YAML at `~/.config/default-browser-router/config.yaml`
Simple, ordered rule list. Parsed with **Yams**. Created with a documented default template on first run if missing. Reloaded on every URL event (config is tiny; cost is negligible) so edits apply immediately.

Proposed shape:
```yaml
# First matching rule wins, top to bottom.
default: com.brave.Browser        # catch-all browser (bundle id or friendly name)
rules:
  - domain: bitbucket.org         # matches host == domain or *.domain
    browser: Safari
  - domain: amazon.com
    browser: Firefox
  - prefix: https://meet.google.com/   # matches URL string prefix
    browser: com.google.Chrome
```
Browsers may be given as a friendly name (`Safari`, `Firefox`) resolved via a small built-in name→bundle-id map, or as an explicit bundle id. Bundle id always wins if it looks like one (contains a dot).

### Matching semantics: ordered, first-match-wins
- `domain: example.com` matches when the URL host equals `example.com` **or** ends with `.example.com` (subdomain suffix). Case-insensitive; leading `www.` is not special-cased beyond the suffix rule.
- `prefix: <str>` matches when the full normalized URL string starts with `<str>`.
- Rules are evaluated top-to-bottom; the first match wins. If none match, use `default`.
- A rule with both `domain` and `prefix` is invalid (config validation error).

### Error handling: fail safe to default
- Missing/invalid config → log, create/keep default template, route to a hardcoded fallback (system default browser resolution excluding self, or first available of Safari/Brave).
- Target browser not installed → fall back to `default`; if `default` also missing → fall back to Safari (always present on macOS).
- Never silently drop a URL.

## Risks / Trade-offs

- **Registering as default browser is finicky and requires codesigning** → Document the exact steps (codesign, register with `lsregister`, select in System Settings). Provide a helper to trigger the "set default browser" prompt via `LSSetDefaultHandlerForURLScheme`.
- **Infinite loop risk (app opens URL in itself)** → Always launch via explicit target bundle id, never the generic default handler; validate that no rule/default resolves to our own bundle id.
- **Reloading config on every event adds latency** → Config is a few KB; parse time is sub-millisecond. Acceptable; can add mtime-cache later if needed.
- **Friendly-name → bundle-id map can get stale** → Prefer bundle ids in docs; treat the name map as convenience only, and fall back to `NSWorkspace.urlForApplication(withBundleIdentifier:)` / name lookup.
- **Not App Store distributable** → Accept; distribute as a signed/notarized `.app` (zip or dmg). Out of scope for v1 to notarize, but codesigning locally is required for testing.
- **Rapid bursts of links** → Process each event independently; acceptable for v1. Batching/resident mode is a possible later optimization.

## Open Questions

- Should the app terminate after each URL or stay resident for a short idle window? (Default: terminate after handling; revisit if launch latency is noticeable.)
- Do we ship a bundled default `config.yaml` example, and where do we document the browser name→bundle-id map?
- Is a minimal `--set-default` / `--install` CLI subcommand worth adding to ease first-time registration?

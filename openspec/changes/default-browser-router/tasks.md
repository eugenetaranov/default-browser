## 1. Project scaffolding

- [x] 1.1 Create an Xcode macOS app project (Swift + AppKit) named `DefaultBrowserRouter` with an app bundle target
  <!-- Implemented as a SwiftPM package + `scripts/bundle.sh` that assembles the .app bundle. Only Command Line Tools are installed (no xcodebuild), and this is fully CLI-reproducible. -->
- [x] 1.2 Add the Yams package dependency (SwiftPM) for YAML parsing
- [x] 1.3 Configure `Info.plist`: set `LSUIElement` = YES (headless, no Dock/menu bar)
- [x] 1.4 Configure `Info.plist` `CFBundleURLTypes` declaring `http` and `https` URL schemes with an appropriate `LSHandlerRank`
- [x] 1.5 Set up local codesigning (development identity) so the bundle can register as a default browser
  <!-- bundle.sh codesigns ad-hoc by default; pass --sign "Developer ID Application: ..." for a real identity. -->

## 2. URL reception (browser-registration)

- [x] 2.1 Implement `AppDelegate` and register a `GetURL` Apple Event handler in `applicationWillFinishLaunching`
- [x] 2.2 Implement `application(_:open:)` / event handler to extract one or more opened URLs
- [x] 2.3 Forward each received URL to the routing entry point (route independently for multi-URL events)
- [x] 2.4 Decide and implement lifecycle: app stays resident (menu bar indicator); no auto-terminate
  <!-- Superseded by the menu bar feature (section 8): the original auto-terminate was removed so the status item persists. -->

## 3. Config model & loading (yaml-config)

- [x] 3.1 Define config model types: `Config { default: String, rules: [Rule] }`, `Rule { domain?, prefix?, browser }`
- [x] 3.2 Resolve config path `~/.config/default-browser-router/config.yaml` (expand home dir)
- [x] 3.3 On missing config, create directory + write default template (catch-all `default` + commented example rules)
- [x] 3.4 Load and parse YAML with Yams into the config model on each URL event
- [x] 3.5 Validate rules: exactly one of `domain`/`prefix` per rule; report invalid rules
- [x] 3.6 On malformed/invalid YAML, log and fall back safely (do not crash, do not drop URL)

## 4. Browser resolution (yaml-config)

- [x] 4.1 Build the friendly-name → bundle-id map (Safari, Firefox, Brave, Chrome, Edge, Arc, etc.)
- [x] 4.2 Implement resolver: treat values containing a dot as bundle ids; otherwise map friendly name
- [x] 4.3 Check installation via `NSWorkspace.urlForApplication(withBundleIdentifier:)`
- [x] 4.4 Guard against resolving to the app's own bundle id (prevent open loop)

## 5. Routing engine (url-routing)

- [x] 5.1 Implement domain matching: host == domain OR host ends with `.domain`, case-insensitive
- [x] 5.2 Implement prefix matching: normalized URL string starts with prefix
- [x] 5.3 Implement first-match-wins evaluation over ordered rules
- [x] 5.4 Implement default fallback when no rule matches
- [x] 5.5 Implement missing-browser fallback chain: matched → default → Safari
- [x] 5.6 Launch original unmodified URL in resolved browser via `NSWorkspace.open(_:withApplicationAt:configuration:)`

## 6. Registration helper & docs

- [x] 6.1 Add a helper to trigger the "set default browser" prompt via `LSSetDefaultHandlerForURLScheme` (optional CLI flag or first-run action)
- [x] 6.2 Write README: build, codesign, register with `lsregister`, select in System Settings, config format + browser name→bundle-id reference

## 7. Testing & verification

- [x] 7.1 Unit tests for domain matching (exact, subdomain, non-matching sibling)
- [x] 7.2 Unit tests for prefix matching (match / non-match)
- [x] 7.3 Unit tests for first-match-wins ordering and default fallback
- [x] 7.4 Unit tests for config parsing (valid, both-domain-and-prefix invalid, malformed YAML)
- [x] 7.5 Unit tests for browser resolution (friendly name, explicit bundle id, self-guard)
- [ ] 7.6 Manual end-to-end: set as default browser, click links matching each rule + a default, confirm correct browser opens
  <!-- Requires the user to select the app as default browser in System Settings and click real links; can't be done autonomously. Build is verified: 25/25 unit tests pass and the codesigned .app assembles and validates. -->

## 8. Menu bar status item

- [x] 8.1 Bump deployment target to macOS 13 (`Package.swift`, `Info.plist`) for `SMAppService`
- [x] 8.2 Add `LoginItem` wrapper over `SMAppService.mainApp` (isEnabled / enable / disable)
- [x] 8.3 Add `StatusItemController`: `NSStatusItem` with SF Symbol `link` template image
- [x] 8.4 Build status menu: About (standard panel), Open at Login (checkmark toggle), Quit
- [x] 8.5 Wire into `AppDelegate`; register login item on first launch; remove auto-terminate logic
- [x] 8.6 Update README (menu bar, macOS 13 requirement) and OpenSpec artifacts
- [ ] 8.7 Manual check: launch app, confirm menu bar icon + menu; toggle Open at Login persists; Quit removes icon; app no longer self-terminates after opening a link

## 9. Distribution & first-run

- [x] 9.1 Add first-run onboarding: on first launch, if not already default, trigger the macOS set-default prompt (`DefaultBrowserPrompt`), guarded by a UserDefaults flag
- [x] 9.2 Document Homebrew Cask distribution + notarization + headless first-run steps in README
- [ ] 9.3 Set up Developer ID signing + notarization + a release cask (requires an Apple Developer account)

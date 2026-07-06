## Why

Different sites are best opened in different browsers (work SSO in Safari, shopping in Firefox, everything else in Brave), but macOS only allows one default browser. Choosy solves this but is paid and heavier than needed. We want a minimal, native macOS app that registers as the default browser and transparently routes each opened link to the right browser based on a simple, hand-editable YAML config.

## What Changes

- Ship a native macOS `.app` bundle that declares itself an `http`/`https` URL handler so it can be selected as the system default browser.
- Run as a background/agent app with no Dock icon; show a minimal menu bar status item (link glyph) as a running indicator, with an About / Open at Login / Quit menu. Its core job is to receive URL-open events and forward them.
- Stay resident (launch at login via `SMAppService`) so the indicator is always present; requires macOS 13+.
- On each opened URL, match it against ordered rules from a YAML config and launch the URL in the chosen browser via the system.
- Support two match types per rule — exact/suffix **domain** match and **prefix** (URL-prefix) match — plus a catch-all `default` browser.
- Read config from a fixed path (e.g. `~/.config/default-browser-router/config.yaml`), created with sensible defaults on first run if absent, and reloaded on each launch/event so edits take effect without a rebuild.
- Provide clear behavior when a target browser is missing or config is invalid (fall back to default browser, never drop the URL).

## Capabilities

### New Capabilities
- `browser-registration`: Register the app as an installable, selectable macOS default browser and receive incoming `http`/`https` open-URL events.
- `yaml-config`: Locate, create-on-first-run, load, and validate the YAML rules file into an in-memory routing table.
- `url-routing`: Match an incoming URL against ordered domain/prefix rules and resolve the target browser, then launch the URL in it (with default fallback).
- `menu-bar`: Show a menu bar status item as a running indicator, with About / Open at Login / Quit, and keep the app resident.
- `rule-editor`: A visual editor (opened from the menu bar) for multi-condition All/Any rules, persisted to the YAML config.

### Modified Capabilities
<!-- None: greenfield project with no existing specs. -->

## Impact

- **New codebase**: Swift + AppKit macOS app (no existing code to modify).
- **Dependencies**: YAML parser (Yams) for config; system `NSWorkspace`/`LaunchServices` for registration and launching browsers.
- **Packaging**: `.app` bundle with `Info.plist` declaring `CFBundleURLTypes` and `LSUIElement`; must be codesigned to register reliably as default browser.
- **System integration**: Registers with LaunchServices; user must select it in System Settings → Desktop & Dock → Default web browser.

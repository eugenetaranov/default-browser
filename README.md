# default-browser-router

A tiny, native macOS app that registers as your **default web browser** and routes
each opened link to a different browser based on a simple YAML config — like Choosy,
but minimal, headless, and free.

- No Dock icon. A small **menu bar icon** (a monochrome link glyph) shows it's running.
- Rules match by **domain** (host or subdomain) or **URL prefix**, first match wins.
- A catch-all `default` browser handles everything else.
- Config is a single YAML file you can hand-edit; changes apply on the next click.
- Runs at login and stays resident; quit any time from the menu bar.

## How it works

macOS sends every clicked `http`/`https` link to the one app set as the default
browser. This app *is* that app: it receives each URL, matches it against your rules,
and immediately re-opens it in the target browser via `NSWorkspace`. It never opens
links in itself (loop-guarded) and always falls back safely so a URL is never dropped.

## Requirements

- macOS 13+ (the "Open at Login" support uses `SMAppService`)
- Swift toolchain (Xcode or Command Line Tools: `xcode-select --install`)

## Build & install

```bash
# 1. Build a codesigned .app bundle (ad-hoc signature, fine for local use)
./scripts/bundle.sh

# Or a release build signed with your Developer ID and registered with LaunchServices:
./scripts/bundle.sh --release --sign "Developer ID Application: Your Name (TEAMID)" --register
```

The bundle is written to `build/DefaultBrowserRouter.app`. Move it to `/Applications`
(recommended so LaunchServices keeps a stable record):

```bash
cp -R build/DefaultBrowserRouter.app /Applications/
# Register it so macOS knows about the http/https handler:
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/DefaultBrowserRouter.app
```

## Installing via Homebrew

Distribute as a **Homebrew Cask** (casks are for `.app` bundles). A cask installs the
app into `/Applications` — the stable, LaunchServices-visible location the app needs to
register as a default browser and to use "Open at Login".

```ruby
# Casks/default-browser-router.rb
cask "default-browser-router" do
  version "1.0"
  sha256 "…"

  url "https://github.com/<you>/default-browser-router/releases/download/v#{version}/DefaultBrowserRouter.zip"
  name "Default Browser Router"
  desc "Routes links to different browsers by YAML rules"
  homepage "https://github.com/<you>/default-browser-router"

  depends_on macos: ">= :ventura"   # macOS 13+

  app "DefaultBrowserRouter.app"

  caveats <<~EOS
    Default Browser Router runs from the menu bar (a link icon) — there is no window.

    This build is ad-hoc signed (not notarized), so install it without quarantine:
      brew install --cask --no-quarantine default-browser-router

    First run:
      1. Launch it once:  open -a "Default Browser Router"
      2. Confirm the "make this your default browser?" prompt it shows, OR set it
         manually in System Settings → Desktop & Dock → Default web browser.
      3. Edit rules at ~/.config/default-browser-router/config.yaml
  EOS
end
```

### No Developer ID? Ship an ad-hoc build

You do **not** need a paid Apple Developer account. `scripts/bundle.sh` already **ad-hoc
signs** the app (`codesign -s -`), which is a real signature — enough to run (arm64
requires *a* signature; ad-hoc counts) and to register as the default browser.

The only catch is Gatekeeper **quarantine** on downloaded copies. Because the build isn't
notarized, avoid quarantine at install time with Homebrew's flag:

```bash
brew install --cask --no-quarantine default-browser-router
```

That's the whole workaround — no notarization step. (If someone installs *with*
quarantine anyway, they can clear it: `xattr -dr com.apple.quarantine
/Applications/DefaultBrowserRouter.app`, or right-click the app → **Open** once.)

To produce the release zip for your cask's `url`:

```bash
./scripts/bundle.sh --release          # ad-hoc signed, no account needed
ditto -c -k --keepParent build/DefaultBrowserRouter.app DefaultBrowserRouter.zip
shasum -a 256 DefaultBrowserRouter.zip  # sha256 for the cask
```

> **Caveat — "Open at Login":** the `SMAppService` login-item API expects a proper code
> signature and may refuse to register for an ad-hoc build (the app logs the failure and
> keeps working; the menu toggle just won't stick). If you need reliable launch-at-login
> without a Dev ID, the fallback is a user `LaunchAgent` plist in
> `~/Library/LaunchAgents/` — ask and it can be wired up. Everything else (routing,
> default-browser registration, the menu bar item) works fine ad-hoc.
>
> **Optional — if you later get a Developer ID**, notarizing removes the `--no-quarantine`
> requirement entirely:
>
> ```bash
> ./scripts/bundle.sh --release --sign "Developer ID Application: Your Name (TEAMID)"
> ditto -c -k --keepParent build/DefaultBrowserRouter.app DefaultBrowserRouter.zip
> xcrun notarytool submit DefaultBrowserRouter.zip --keychain-profile "AC_NOTARY" --wait
> xcrun stapler staple build/DefaultBrowserRouter.app
> ```

### First run (what to expect)

Because the app is headless (menu bar only, no Dock icon, no window), the first launch:

1. Adds the **link icon to your menu bar** (proof it's running).
2. Registers as an available http/https handler with LaunchServices.
3. On the *first* launch only, shows the macOS **"set default browser?"** prompt so you
   can accept in one click. (If you decline, set it later via the menu bar or System
   Settings, or run `--set-default`.)
4. Registers itself as a **login item** so it starts on next login (toggle off any time
   via the menu bar → *Open at Login*).

If you installed an ad-hoc build *with* quarantine and Gatekeeper blocks it, either
reinstall with `--no-quarantine`, right-click the app → **Open**, or clear quarantine:

```bash
xattr -dr com.apple.quarantine /Applications/DefaultBrowserRouter.app
```

## Set it as the default browser

Either:

- **System Settings → Desktop & Dock → Default web browser** → choose
  *Default Browser Router*, **or**
- run the built-in helper (prompts for confirmation):

  ```bash
  /Applications/DefaultBrowserRouter.app/Contents/MacOS/DefaultBrowserRouter --set-default
  ```

> Note: reliable default-browser registration generally requires a codesigned bundle
> living in a stable location (e.g. `/Applications`). Ad-hoc signing works for testing
> on the same machine.

## Menu bar

While running, the app shows a monochrome link icon in the menu bar (its only UI —
there is no Dock icon or window). Clicking it opens a menu with:

- **About Default Browser Router** — standard about panel.
- **Open at Login** — toggles launch-at-login registration (`SMAppService`); the
  checkmark reflects the current state.
- **Quit** — exits the app (it will relaunch on the next clicked link, or at next login
  if "Open at Login" is enabled).

The app stays resident once launched, so the icon remains until you quit.

## Configuration

Config lives at:

```
~/.config/default-browser-router/config.yaml
```

It's created with a default template on first run. Example:

```yaml
# First matching rule wins, evaluated top to bottom.
default: Brave

rules:
  - domain: bitbucket.org          # matches bitbucket.org and any subdomain
    browser: Safari
  - domain: amazon.com
    browser: Firefox
  - prefix: https://meet.google.com/   # matches a URL string prefix
    browser: Chrome
```

### Rule semantics

- `domain: example.com` matches when the URL host equals `example.com` **or** ends
  with `.example.com` (any subdomain). Case-insensitive.
- `prefix: https://...` matches when the full URL string starts with that text.
- Each rule must have **exactly one** of `domain` or `prefix`.
- Rules are evaluated top-to-bottom; the **first match wins**.
- If nothing matches, the `default` browser is used.

### Specifying browsers

`browser` (and `default`) accept either a **friendly name** or an explicit
**bundle identifier** (any value containing a dot is treated as a bundle id).

| Friendly name | Bundle identifier |
|---------------|-------------------|
| Safari        | com.apple.Safari |
| Firefox       | org.mozilla.firefox |
| Brave         | com.brave.Browser |
| Chrome        | com.google.Chrome |
| Edge          | com.microsoft.edgemac |
| Arc           | company.thebrowser.Browser |
| Opera         | com.operasoftware.Opera |
| Vivaldi       | com.vivaldi.Vivaldi |
| Chromium      | org.chromium.Chromium |

For anything not listed, use the bundle id directly, e.g.:

```yaml
- domain: figma.com
  browser: com.figma.Desktop
```

Find a browser's bundle id with:

```bash
osascript -e 'id of app "Brave Browser"'
```

### Fallback behavior

If a rule's browser isn't installed, the app falls back to `default`; if that's also
unavailable, it falls back to **Safari** (always present). Malformed config is logged
and the current link is opened in Safari rather than lost.

## Develop & test

```bash
swift build            # build everything
swift run RouterTests   # run the routing/config test suite
```

`RouterTests` is a self-contained runner (no XCTest dependency) so it works with a
Command-Line-Tools-only toolchain. The routing/config logic lives in the `RouterCore`
library; the AppKit executable (`DefaultBrowserRouter`) only handles URL reception and
launching.

## Project layout

```
Sources/RouterCore/            # pure, testable logic
  Config.swift                 # YAML model, parsing, validation
  ConfigStore.swift            # path resolution + first-run template
  BrowserResolver.swift        # name -> bundle-id map + dot detection
  Router.swift                 # matching engine + fallback chain
Sources/DefaultBrowserRouter/  # headless AppKit app
  main.swift                   # entry + --set-default helper
  AppDelegate.swift            # GetURL Apple Event + routing + lifecycle
  BrowserLauncher.swift        # NSWorkspace launch wrapper
Sources/RouterTests/           # self-contained test runner
Resources/Info.plist           # LSUIElement + CFBundleURLTypes
scripts/bundle.sh              # build + assemble .app + codesign (+ register)
```

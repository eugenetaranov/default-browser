# default-browser-router

A tiny, native macOS app that registers as your **default web browser** and routes each
opened link to a different browser based on a simple YAML config — like Choosy, but
minimal, headless, and free.

## How it works

macOS sends every clicked `http`/`https` link to the one app set as the default browser.
This app *is* that app: it receives each URL, matches it against your rules (by **domain**
or **URL prefix**, first match wins), and immediately re-opens it in the target browser. A
catch-all `default` handles everything else. It runs headless with just a menu bar icon
(About / Open at Login / Quit); config is reloaded on every click, and any error falls back
to the default browser so a link is never lost.

Requires macOS 13+.

## Install with Homebrew

```bash
brew tap eugenetaranov/homebrew-tap
brew trust eugenetaranov/tap        # Homebrew requires trusting third-party taps
brew install --cask default-browser-router
```

The build is ad-hoc signed (not notarized), so clear the download quarantine once, then
launch it and make it your default browser:

```bash
xattr -dr com.apple.quarantine "/Applications/DefaultBrowserRouter.app"
open -a "Default Browser Router"
```

On first launch it shows a "make this your default browser?" prompt — accept it (or set it
manually in **System Settings → Desktop & Dock → Default web browser**).

## Build & install locally

```bash
./scripts/bundle.sh                       # build + assemble + ad-hoc codesign
cp -R build/DefaultBrowserRouter.app /Applications/
open -a "Default Browser Router"          # launch once, then set as default browser
```

Develop:

```bash
swift build
swift run RouterTests                     # routing/config test suite
```

## Configuration

Config lives at `~/.config/default-browser-router/config.yaml` (created on first run):

```yaml
# First matching rule wins, top to bottom.
default: Brave

rules:
  - domain: bitbucket.org          # matches bitbucket.org and any subdomain
    browser: Safari
  - domain: amazon.com
    browser: Firefox
  - prefix: https://meet.google.com/   # matches a URL string prefix
    browser: Chrome
```

- `domain` matches the host or any subdomain (case-insensitive); `prefix` matches the start
  of the full URL. Each rule has exactly one of the two.
- `browser` (and `default`) accept a friendly name (`Safari`, `Firefox`, `Brave`, `Chrome`,
  `Edge`, `Arc`, `Vivaldi`, `Opera`, `Chromium`) or an explicit bundle id (any value with a
  dot, e.g. `com.brave.Browser`). Find one with `osascript -e 'id of app "Brave Browser"'`.
- If a rule's browser isn't installed, it falls back to `default`, then Safari.

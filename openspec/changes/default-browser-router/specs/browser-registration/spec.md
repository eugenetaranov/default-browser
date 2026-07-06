## ADDED Requirements

### Requirement: Selectable as macOS default browser
The app SHALL ship as a codesigned macOS `.app` bundle whose `Info.plist` declares `http` and `https` URL schemes (via `CFBundleURLTypes`) so that macOS lists it as a candidate default web browser and allows the user to select it in System Settings.

#### Scenario: App appears in default browser list
- **WHEN** the built and codesigned app is registered with LaunchServices and the user opens System Settings → Desktop & Dock → Default web browser
- **THEN** the app is available for selection as the default web browser

#### Scenario: Selected as default receives links
- **WHEN** the app is set as the default web browser and the user clicks an `http`/`https` link in any application
- **THEN** the operating system delivers that URL to the app

### Requirement: Headless background operation
The app SHALL run without any Dock icon, window, or menu bar item by declaring `LSUIElement` (agent) behavior, so it operates invisibly as a URL router.

#### Scenario: No visible UI on launch
- **WHEN** the app is launched to handle a URL
- **THEN** no Dock icon, application window, or menu bar item appears

### Requirement: Receive opened URLs
The app SHALL receive one or more opened URLs per system event via the URL open callback / `GetURL` Apple Event and pass each to routing.

#### Scenario: Single URL delivered
- **WHEN** the system opens a single `https` URL with the app
- **THEN** the app receives the exact URL string and forwards it to the routing logic

#### Scenario: Multiple URLs delivered in one event
- **WHEN** the system opens more than one URL in a single event
- **THEN** the app routes each URL independently

### Requirement: First-run default-browser onboarding
On its first launch only, if the app is not already the default browser, it SHALL surface the macOS "set default browser" prompt so a headless install has an actionable first-run step. It SHALL NOT re-prompt on subsequent launches.

#### Scenario: First launch, not yet default
- **WHEN** the app launches for the first time and is not the current default browser
- **THEN** it requests default-handler status, causing macOS to prompt the user to confirm

#### Scenario: Subsequent launches
- **WHEN** the app launches after the first run
- **THEN** it does not re-show the set-default prompt

### Requirement: Never route to itself
The app SHALL NOT launch a URL using its own bundle identifier or the generic system default handler, preventing an infinite open loop.

#### Scenario: Resolved target equals self
- **WHEN** routing resolves a target whose bundle identifier equals the app's own bundle identifier
- **THEN** the app treats it as invalid and falls back to a different installed browser instead of re-opening the URL in itself

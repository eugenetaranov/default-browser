## ADDED Requirements

### Requirement: Menu bar running indicator
While running, the app SHALL display a monochrome menu bar status item (a link glyph) as an indicator that the router is active. The app SHALL have no Dock icon.

#### Scenario: Icon visible while running
- **WHEN** the app is running
- **THEN** a monochrome link icon is shown in the macOS menu bar and no Dock icon is present

### Requirement: Status item menu
The status item SHALL present a menu containing at least "About", "Open at Login", and "Quit" items.

#### Scenario: About opens the about panel
- **WHEN** the user selects "About" from the status item menu
- **THEN** the standard about panel is brought to the front

#### Scenario: Quit terminates the app
- **WHEN** the user selects "Quit" from the status item menu
- **THEN** the app terminates and the menu bar icon is removed

### Requirement: Open at Login toggle
The menu SHALL include an "Open at Login" item whose checked state reflects the current `SMAppService` login-item registration, and selecting it SHALL toggle registration.

#### Scenario: Toggle reflects and updates state
- **WHEN** the user selects "Open at Login" while it is unchecked
- **THEN** the app registers as a login item and the item becomes checked

#### Scenario: Disable login item
- **WHEN** the user selects "Open at Login" while it is checked
- **THEN** the app unregisters the login item and the item becomes unchecked

### Requirement: Resident lifecycle
The app SHALL remain running after handling opened URLs (it SHALL NOT auto-terminate), so the menu bar indicator persists until the user quits.

#### Scenario: Stays running after routing a link
- **WHEN** the app routes an opened URL to a browser
- **THEN** the app remains running and the menu bar icon stays visible

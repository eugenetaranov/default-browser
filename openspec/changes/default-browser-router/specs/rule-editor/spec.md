## ADDED Requirements

### Requirement: Open the rule editor from the menu bar
The menu bar menu SHALL include an "Edit Rules…" item that opens a visual editor window. Because the app is a headless agent, opening the window SHALL bring it to the foreground.

#### Scenario: Editor opens
- **WHEN** the user selects "Edit Rules…" from the menu bar
- **THEN** a rules editor window appears and takes focus

#### Scenario: Returns to headless after closing
- **WHEN** the user closes the editor window
- **THEN** the app returns to headless agent mode (no Dock icon)

### Requirement: Edit rules visually
The editor SHALL let the user set the default browser and add/remove rules; each rule SHALL let the user choose All/Any, add/remove conditions (type + value), and pick the target browser from installed browsers.

#### Scenario: Build a multi-condition rule
- **WHEN** the user adds a rule, sets match to All, adds `source_app = Mail` and `url_contains = facebook`, and selects Safari
- **THEN** the editor holds a rule equivalent to that configuration

### Requirement: Persist edits to the config file
Saving in the editor SHALL write the rules to `~/.config/default-browser-router/config.yaml` in the supported schema, so the router picks them up on the next opened link.

#### Scenario: Save writes YAML
- **WHEN** the user clicks Save
- **THEN** the config file is rewritten with the current rules and parses back to the same configuration

#### Scenario: Load reflects current file
- **WHEN** the editor is opened
- **THEN** it is populated from the current config file

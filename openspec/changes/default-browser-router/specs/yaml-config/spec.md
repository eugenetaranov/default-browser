## ADDED Requirements

### Requirement: Config file location and first-run creation
The app SHALL read its configuration from a fixed path at `~/.config/default-browser-router/config.yaml`. If the file does not exist, the app SHALL create it with a documented default template on first run.

#### Scenario: Config missing on first run
- **WHEN** the app runs and no config file exists at the expected path
- **THEN** the app creates the directory and a default `config.yaml` containing a catch-all `default` browser and commented example rules

#### Scenario: Config present
- **WHEN** the app runs and a config file exists
- **THEN** the app loads it without overwriting the user's content

### Requirement: Config schema and parsing
The config SHALL be YAML with a required `default` browser and an optional ordered `rules` list, where each rule has exactly one of `domain` or `prefix` plus a `browser`. The app SHALL parse this into an in-memory routing table.

#### Scenario: Valid config parses
- **WHEN** the config contains a `default` and a list of rules each with a single `domain` or `prefix` and a `browser`
- **THEN** the app builds an ordered routing table preserving rule order

#### Scenario: Rule with both domain and prefix
- **WHEN** a rule specifies both `domain` and `prefix`
- **THEN** the app reports the rule as invalid

### Requirement: Config reloaded per event
The app SHALL load the current config for each URL-open event so that edits to the file take effect without rebuilding or restarting.

#### Scenario: Edited config applies immediately
- **WHEN** the user edits `config.yaml` and then opens a link
- **THEN** the routing uses the updated rules

### Requirement: Invalid config fails safe
The app SHALL NOT crash on malformed or invalid YAML. It SHALL log the error and continue routing using the default fallback so no URL is dropped.

#### Scenario: Malformed YAML
- **WHEN** the config file contains YAML that cannot be parsed
- **THEN** the app logs the error and routes the current URL to a safe fallback browser

### Requirement: Browser identifier resolution
A `browser` value SHALL be interpretable either as an explicit bundle identifier or as a friendly name resolved via a built-in name→bundle-id map. A value containing a dot SHALL be treated as a bundle identifier.

#### Scenario: Friendly name resolves
- **WHEN** a rule specifies `browser: Safari`
- **THEN** the app resolves it to the corresponding bundle identifier `com.apple.Safari`

#### Scenario: Explicit bundle id used directly
- **WHEN** a rule specifies `browser: com.brave.Browser`
- **THEN** the app uses that bundle identifier without name lookup

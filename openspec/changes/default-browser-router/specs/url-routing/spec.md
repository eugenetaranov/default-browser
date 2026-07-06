## ADDED Requirements

### Requirement: Domain matching
A rule of type `domain` SHALL match a URL when the URL's host equals the configured domain or is a subdomain of it (host ends with `.` + domain). Matching SHALL be case-insensitive.

#### Scenario: Exact host match
- **WHEN** a rule is `domain: amazon.com` and the opened URL is `https://amazon.com/gp/cart`
- **THEN** the rule matches

#### Scenario: Subdomain match
- **WHEN** a rule is `domain: amazon.com` and the opened URL is `https://www.amazon.com/`
- **THEN** the rule matches

#### Scenario: Non-matching sibling domain
- **WHEN** a rule is `domain: amazon.com` and the opened URL host is `notamazon.com`
- **THEN** the rule does not match

### Requirement: Prefix matching
A rule of type `prefix` SHALL match a URL when the URL's full normalized string starts with the configured prefix.

#### Scenario: URL starts with prefix
- **WHEN** a rule is `prefix: https://meet.google.com/` and the opened URL is `https://meet.google.com/abc-defg-hij`
- **THEN** the rule matches

#### Scenario: URL does not start with prefix
- **WHEN** a rule is `prefix: https://meet.google.com/` and the opened URL is `https://mail.google.com/`
- **THEN** the rule does not match

### Requirement: First-match-wins ordering
The app SHALL evaluate rules top-to-bottom and route the URL to the browser of the first matching rule.

#### Scenario: Earlier rule wins over later
- **WHEN** two rules could match the same URL
- **THEN** the app uses the browser from the rule listed first

### Requirement: Default fallback
When no rule matches, the app SHALL route the URL to the browser specified by the config's `default`.

#### Scenario: No rule matches
- **WHEN** the opened URL matches none of the configured rules
- **THEN** the app launches the URL in the `default` browser

### Requirement: Launch URL in resolved browser
The app SHALL open the original, unmodified URL in the resolved target browser using the system launch API addressed by bundle identifier.

#### Scenario: Successful launch
- **WHEN** a URL resolves to an installed target browser
- **THEN** the app opens the exact original URL in that browser

### Requirement: Missing browser fallback
When a resolved target browser is not installed, the app SHALL fall back to the `default` browser, and if that is also unavailable, to Safari, so the URL is always opened.

#### Scenario: Target browser not installed
- **WHEN** a matched rule's browser is not installed but the `default` browser is
- **THEN** the app opens the URL in the `default` browser

#### Scenario: Default also missing
- **WHEN** both the matched browser and the `default` browser are unavailable
- **THEN** the app opens the URL in Safari

## ADDED Requirements

### Requirement: Additional web-address conditions
Rules SHALL support these web-address conditions beyond domain/prefix: `url_contains` (case-insensitive substring of the full URL), `url_equals` (exact full URL), and `url_regex` (regular expression over the full URL; an invalid pattern SHALL never match).

#### Scenario: url_contains matches case-insensitively
- **WHEN** a condition is `url_contains: facebook` and the URL is `https://m.FACEBOOK.com/x`
- **THEN** the condition matches

#### Scenario: url_regex with invalid pattern
- **WHEN** a condition is `url_regex: [` (invalid) for any URL
- **THEN** the condition does not match and routing continues safely

### Requirement: Source application condition
A rule SHALL support a `source_app` condition matching the application that opened the link, by localized name (case-insensitive), or by bundle identifier when the value contains a dot.

#### Scenario: Match by app name
- **WHEN** a condition is `source_app: Mail` and the link was opened by Mail
- **THEN** the condition matches

#### Scenario: Non-matching source app
- **WHEN** a condition is `source_app: Slack` and the link was opened by Mail
- **THEN** the condition does not match

### Requirement: Multi-condition rules with All/Any
A rule SHALL be able to combine multiple conditions via `match: all` (every condition must hold) or `match: any` (at least one). A single inline condition SHALL remain valid and behave as `match: all` with one condition.

#### Scenario: All requires every condition
- **WHEN** a rule is `match: all` with `source_app: Mail` and `url_contains: facebook`, and the link is a facebook URL opened by Slack
- **THEN** the rule does not match

#### Scenario: Any requires one condition
- **WHEN** a rule is `match: any` with domains `amazon.com` and `ebay.com`, and the URL host is `ebay.com`
- **THEN** the rule matches

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

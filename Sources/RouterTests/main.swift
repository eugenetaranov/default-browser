import Foundation
import RouterCore

// Minimal test harness — plain Swift, no XCTest (unavailable with CLT-only toolchains).
var failures = 0
var passed = 0

func check(_ condition: Bool, _ name: String) {
    if condition { passed += 1 } else {
        failures += 1
        FileHandle.standardError.write(Data("FAIL: \(name)\n".utf8))
    }
}

func checkEqual<T: Equatable>(_ a: T, _ b: T, _ name: String) {
    if a == b { passed += 1 } else {
        failures += 1
        FileHandle.standardError.write(Data("FAIL: \(name) — got \(a), expected \(b)\n".utf8))
    }
}

func url(_ s: String) -> URL { URL(string: s)! }
func ctx(_ s: String, app: String? = nil, bundle: String? = nil) -> RequestContext {
    RequestContext(url: url(s), sourceAppName: app, sourceBundleID: bundle)
}
func makeRouter(_ config: Config, installed: Set<String> = ["com.apple.Safari"]) -> Router {
    Router(config: config, selfBundleID: "me.taranov.DefaultBrowserRouter") { installed.contains($0) }
}

// MARK: - Condition matching (7.1 / 7.2)
check(Condition.domain("amazon.com").matches(ctx("https://amazon.com/gp/cart")), "domain exact host")
check(Condition.domain("amazon.com").matches(ctx("https://www.amazon.com/")), "domain subdomain")
check(Condition.domain("amazon.com").matches(ctx("https://WWW.Amazon.COM/")), "domain case-insensitive")
check(!Condition.domain("amazon.com").matches(ctx("https://notamazon.com/")), "domain non-matching sibling")
check(Condition.urlPrefix("https://meet.google.com/").matches(ctx("https://meet.google.com/abc")), "prefix match")
check(!Condition.urlPrefix("https://meet.google.com/").matches(ctx("https://mail.google.com/")), "prefix non-match")
check(Condition.urlContains("facebook").matches(ctx("https://m.facebook.com/x")), "contains match")
check(Condition.urlContains("FACEBOOK").matches(ctx("https://facebook.com/")), "contains case-insensitive")
check(!Condition.urlContains("twitter").matches(ctx("https://facebook.com/")), "contains non-match")
check(Condition.urlEquals("https://example.com/").matches(ctx("https://example.com/")), "equals match")
check(!Condition.urlEquals("https://example.com/").matches(ctx("https://example.com/x")), "equals non-match")
check(Condition.urlRegex(#"^https://.*\.slack\.com/"#).matches(ctx("https://foo.slack.com/x")), "regex match")
check(!Condition.urlRegex(#"^https://.*\.slack\.com/"#).matches(ctx("https://slackcom/")), "regex non-match")
check(!Condition.urlRegex("[").matches(ctx("https://example.com/")), "invalid regex never matches")

// MARK: - Source application (7.5)
check(Condition.sourceApp("Mail").matches(ctx("https://x.test/", app: "Mail")), "source app by name")
check(Condition.sourceApp("mail").matches(ctx("https://x.test/", app: "Mail")), "source app case-insensitive")
check(!Condition.sourceApp("Slack").matches(ctx("https://x.test/", app: "Mail")), "source app non-match")
check(Condition.sourceApp("com.apple.mail").matches(ctx("https://x.test/", bundle: "com.apple.mail")), "source app by bundle id")
check(!Condition.sourceApp("com.apple.mail").matches(ctx("https://x.test/", app: "Mail")), "bundle-id form ignores name")

// MARK: - All/Any combinator
let allRule = Rule(match: .all, conditions: [.sourceApp("Mail"), .urlContains("facebook")], browser: "Safari")
check(allRule.matches(ctx("https://facebook.com/", app: "Mail")), "all: both true")
check(!allRule.matches(ctx("https://facebook.com/", app: "Slack")), "all: one false")
let anyRule = Rule(match: .any, conditions: [.domain("amazon.com"), .domain("ebay.com")], browser: "Firefox")
check(anyRule.matches(ctx("https://ebay.com/")), "any: one true")
check(!anyRule.matches(ctx("https://etsy.com/")), "any: none true")

// MARK: - Routing (first-match-wins, default + fallback)
let ordered = Config(defaultBrowser: "Brave", rules: [
    Rule(conditions: [.domain("example.com")], browser: "Safari"),
    Rule(conditions: [.domain("example.com")], browser: "Firefox"),
])
checkEqual(makeRouter(ordered).matchedBrowserValue(for: ctx("https://example.com/")), "Safari", "first-match-wins")

let noMatch = Config(defaultBrowser: "Brave", rules: [Rule(conditions: [.domain("amazon.com")], browser: "Firefox")])
checkEqual(makeRouter(noMatch, installed: ["com.brave.Browser", "com.apple.Safari"])
    .resolveTargetBundleID(for: ctx("https://nowhere.test/")), "com.brave.Browser", "default fallback")
checkEqual(makeRouter(noMatch, installed: ["com.brave.Browser", "com.apple.Safari"])
    .resolveTargetBundleID(for: ctx("https://amazon.com/")), "com.brave.Browser", "missing target -> default")
checkEqual(makeRouter(noMatch, installed: ["com.apple.Safari"])
    .resolveTargetBundleID(for: ctx("https://amazon.com/")), "com.apple.Safari", "default also missing -> Safari")

// MARK: - Browser resolution + self-guard
checkEqual(BrowserResolver.bundleID(for: "Safari"), "com.apple.Safari", "friendly name resolves")
checkEqual(BrowserResolver.bundleID(for: "com.brave.Browser"), "com.brave.Browser", "explicit bundle id")
check(BrowserResolver.bundleID(for: "NetscapeNavigator") == nil, "unknown friendly name -> nil")
let selfCfg = Config(defaultBrowser: "me.taranov.DefaultBrowserRouter", rules: [])
checkEqual(makeRouter(selfCfg, installed: ["me.taranov.DefaultBrowserRouter", "com.apple.Safari"])
    .resolveTargetBundleID(for: ctx("https://x.test/")), "com.apple.Safari", "never routes to self")

// MARK: - Config parsing (7.4): legacy + new schema
do {
    let cfg = try ConfigLoader.parse("""
    default: Brave
    rules:
      - domain: bitbucket.org
        browser: Safari
      - prefix: https://meet.google.com/
        browser: Chrome
    """)
    checkEqual(cfg.rules.count, 2, "legacy: rule count")
    checkEqual(cfg.rules[0], Rule(match: .all, conditions: [.domain("bitbucket.org")], browser: "Safari"), "legacy: domain rule")
    checkEqual(cfg.rules[1], Rule(match: .all, conditions: [.urlPrefix("https://meet.google.com/")], browser: "Chrome"), "legacy: prefix rule")
} catch { check(false, "legacy config parses (threw \(error))") }

do {
    let cfg = try ConfigLoader.parse("""
    default: Brave
    rules:
      - match: all
        conditions:
          - source_app: Mail
          - url_contains: facebook
        browser: Safari
      - match: any
        conditions:
          - domain: amazon.com
          - domain: ebay.com
        browser: Firefox
    """)
    checkEqual(cfg.rules.count, 2, "new: rule count")
    checkEqual(cfg.rules[0], Rule(match: .all, conditions: [.sourceApp("Mail"), .urlContains("facebook")], browser: "Safari"), "new: all rule")
    checkEqual(cfg.rules[1], Rule(match: .any, conditions: [.domain("amazon.com"), .domain("ebay.com")], browser: "Firefox"), "new: any rule")
} catch { check(false, "new config parses (threw \(error))") }

func expectError(_ yaml: String, _ name: String) {
    do { _ = try ConfigLoader.parse(yaml); check(false, "\(name) — expected throw") }
    catch { check(true, name) }
}
expectError("rules: []", "missing default invalid")
expectError("default: Brave\nrules:\n  - browser: Safari", "rule without conditions invalid")
expectError("default: Brave\nrules:\n  - conditions:\n      - bogus_key: x\n    browser: Safari", "unknown condition key invalid")
expectError("default: Brave\nrules:\n  - match: sometimes\n    conditions:\n      - domain: x\n    browser: Safari", "invalid match invalid")
expectError("default: Brave\n  bad: : [", "malformed yaml throws")

// MARK: - Template + YAML round-trip
do {
    let cfg = try ConfigLoader.parse(ConfigStore.defaultTemplate)
    checkEqual(cfg.defaultBrowser, "Brave", "template default")
    check(cfg.rules.isEmpty, "template has no active rules")
} catch { check(false, "template parses (threw \(error))") }

do {
    let original = Config(defaultBrowser: "Brave", rules: [
        Rule(match: .all, conditions: [.sourceApp("Mail"), .urlContains("facebook")], browser: "Safari"),
        Rule(match: .any, conditions: [.domain("amazon.com")], browser: "Firefox"),
    ])
    let text = try ConfigSerializer.dump(original)
    let reparsed = try ConfigLoader.parse(text)
    checkEqual(reparsed, original, "YAML round-trip preserves config")
} catch { check(false, "round-trip (threw \(error))") }

// MARK: - Summary
print("Tests: \(passed) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)

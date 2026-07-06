import Foundation
import RouterCore

// Minimal test harness — plain Swift, no XCTest (unavailable with CLT-only toolchains).
var failures = 0
var passed = 0

func check(_ condition: Bool, _ name: String) {
    if condition {
        passed += 1
    } else {
        failures += 1
        FileHandle.standardError.write(Data("FAIL: \(name)\n".utf8))
    }
}

func checkEqual<T: Equatable>(_ a: T, _ b: T, _ name: String) {
    if a == b {
        passed += 1
    } else {
        failures += 1
        FileHandle.standardError.write(Data("FAIL: \(name) — got \(a), expected \(b)\n".utf8))
    }
}

func url(_ s: String) -> URL { URL(string: s)! }

func makeRouter(_ config: Config, installed: Set<String> = ["com.apple.Safari"]) -> Router {
    Router(config: config, selfBundleID: "me.taranov.DefaultBrowserRouter") { installed.contains($0) }
}

// MARK: - Domain matching (7.1)
check(RuleMatcher.domainMatches("amazon.com", url: url("https://amazon.com/gp/cart")), "domain exact host")
check(RuleMatcher.domainMatches("amazon.com", url: url("https://www.amazon.com/")), "domain subdomain")
check(RuleMatcher.domainMatches("amazon.com", url: url("https://WWW.Amazon.COM/")), "domain case-insensitive")
check(!RuleMatcher.domainMatches("amazon.com", url: url("https://notamazon.com/")), "domain non-matching sibling")

// MARK: - Prefix matching (7.2)
check(RuleMatcher.prefixMatches("https://meet.google.com/", url: url("https://meet.google.com/abc-defg-hij")), "prefix match")
check(!RuleMatcher.prefixMatches("https://meet.google.com/", url: url("https://mail.google.com/")), "prefix non-match")

// MARK: - First-match-wins + default fallback (7.3)
let ordered = Config(defaultBrowser: "Brave", rules: [
    Rule(domain: "example.com", browser: "Safari"),
    Rule(domain: "example.com", browser: "Firefox"),
])
checkEqual(makeRouter(ordered).matchedBrowserValue(for: url("https://example.com/")), "Safari", "first-match-wins")

let noMatch = Config(defaultBrowser: "Brave", rules: [Rule(domain: "amazon.com", browser: "Firefox")])
checkEqual(makeRouter(noMatch, installed: ["com.brave.Browser", "com.apple.Safari"])
    .resolveTargetBundleID(for: url("https://nowhere.test/")), "com.brave.Browser", "default fallback")

// MARK: - Missing-browser fallback chain (7.3 / 5.5)
let missing = Config(defaultBrowser: "Brave", rules: [Rule(domain: "amazon.com", browser: "Firefox")])
checkEqual(makeRouter(missing, installed: ["com.brave.Browser", "com.apple.Safari"])
    .resolveTargetBundleID(for: url("https://amazon.com/")), "com.brave.Browser", "missing target -> default")
checkEqual(makeRouter(missing, installed: ["com.apple.Safari"])
    .resolveTargetBundleID(for: url("https://amazon.com/")), "com.apple.Safari", "default also missing -> Safari")

// MARK: - Browser resolution + self-guard (7.5 / 4.4)
checkEqual(BrowserResolver.bundleID(for: "Safari"), "com.apple.Safari", "friendly name resolves")
checkEqual(BrowserResolver.bundleID(for: "firefox"), "org.mozilla.firefox", "friendly name lowercase")
checkEqual(BrowserResolver.bundleID(for: "com.brave.Browser"), "com.brave.Browser", "explicit bundle id")
check(BrowserResolver.bundleID(for: "NetscapeNavigator") == nil, "unknown friendly name -> nil")
let selfCfg = Config(defaultBrowser: "me.taranov.DefaultBrowserRouter", rules: [])
checkEqual(makeRouter(selfCfg, installed: ["me.taranov.DefaultBrowserRouter", "com.apple.Safari"])
    .resolveTargetBundleID(for: url("https://x.test/")), "com.apple.Safari", "never routes to self")

// MARK: - Config parsing (7.4)
do {
    let cfg = try ConfigLoader.parse("""
    default: Brave
    rules:
      - domain: bitbucket.org
        browser: Safari
      - prefix: https://meet.google.com/
        browser: Chrome
    """)
    checkEqual(cfg.defaultBrowser, "Brave", "parse default")
    checkEqual(cfg.rules.count, 2, "parse rule count")
    checkEqual(cfg.rules[0], Rule(domain: "bitbucket.org", browser: "Safari"), "parse rule 0")
    checkEqual(cfg.rules[1], Rule(prefix: "https://meet.google.com/", browser: "Chrome"), "parse rule 1")
} catch {
    check(false, "valid config parses (threw \(error))")
}

func expectError(_ yaml: String, _ expected: ConfigError, _ name: String) {
    do {
        _ = try ConfigLoader.parse(yaml)
        check(false, "\(name) — expected throw, none")
    } catch let e as ConfigError {
        checkEqual(e, expected, name)
    } catch {
        check(false, "\(name) — wrong error type \(error)")
    }
}

expectError("""
default: Brave
rules:
  - domain: example.com
    prefix: https://example.com/
    browser: Safari
""", .ruleHasBothDomainAndPrefix(index: 0), "both domain+prefix invalid")

expectError("""
default: Brave
rules:
  - browser: Safari
""", .ruleHasNeitherDomainNorPrefix(index: 0), "neither domain nor prefix invalid")

expectError("rules: []", .missingDefault, "missing default invalid")

do {
    _ = try ConfigLoader.parse("default: Brave\n  bad: : [")
    check(false, "malformed yaml — expected throw")
} catch { check(true, "malformed yaml throws") }

do {
    let cfg = try ConfigLoader.parse(ConfigStore.defaultTemplate)
    checkEqual(cfg.defaultBrowser, "Brave", "template default")
    check(cfg.rules.isEmpty, "template has no active rules")
} catch {
    check(false, "template parses (threw \(error))")
}

// MARK: - Summary
print("Tests: \(passed) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)

import Foundation

public enum RuleMatcher {
    /// Domain match: URL host equals `domain` or is a subdomain of it. Case-insensitive.
    public static func domainMatches(_ domain: String, url: URL) -> Bool {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return false }
        let d = domain.lowercased()
        return host == d || host.hasSuffix("." + d)
    }

    /// Prefix match: the full URL string starts with `prefix`. Case-sensitive.
    public static func prefixMatches(_ prefix: String, url: URL) -> Bool {
        return url.absoluteString.hasPrefix(prefix)
    }

    /// Whether a rule matches a URL, based on its single populated matcher.
    public static func matches(_ rule: Rule, url: URL) -> Bool {
        if let domain = rule.domain {
            return domainMatches(domain, url: url)
        }
        if let prefix = rule.prefix {
            return prefixMatches(prefix, url: url)
        }
        return false
    }
}

public struct Router {
    let config: Config
    let selfBundleID: String?
    let isInstalled: (String) -> Bool

    /// - Parameters:
    ///   - config: the parsed configuration.
    ///   - selfBundleID: this app's own bundle id, never routed to (prevents open loops).
    ///   - isInstalled: predicate deciding whether a bundle id is installed (injected for testing).
    public init(config: Config, selfBundleID: String?, isInstalled: @escaping (String) -> Bool) {
        self.config = config
        self.selfBundleID = selfBundleID
        self.isInstalled = isInstalled
    }

    /// The `browser` config value chosen for a URL: first matching rule, else default.
    public func matchedBrowserValue(for url: URL) -> String {
        for rule in config.rules where RuleMatcher.matches(rule, url: url) {
            return rule.browser
        }
        return config.defaultBrowser
    }

    /// Resolve the final target bundle id for a URL.
    ///
    /// Candidate chain: matched rule's browser -> config `default` -> Safari.
    /// Each candidate must resolve to a bundle id, be installed, and not equal `selfBundleID`.
    public func resolveTargetBundleID(for url: URL) -> String? {
        let candidates = [
            matchedBrowserValue(for: url),
            config.defaultBrowser,
            BrowserResolver.safariBundleID,
        ]
        for value in candidates {
            guard let bundleID = BrowserResolver.bundleID(for: value) else { continue }
            if let selfBundleID, bundleID.caseInsensitiveCompare(selfBundleID) == .orderedSame {
                continue
            }
            if isInstalled(bundleID) {
                return bundleID
            }
        }
        return nil
    }
}

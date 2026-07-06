import Foundation

/// Everything known about an opened link at routing time.
public struct RequestContext {
    public let url: URL
    public let sourceAppName: String?
    public let sourceBundleID: String?

    public init(url: URL, sourceAppName: String? = nil, sourceBundleID: String? = nil) {
        self.url = url
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
    }
}

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

    /// Regex match against the full URL string. Invalid patterns never match.
    public static func regexMatches(_ pattern: String, url: URL) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let s = url.absoluteString
        return regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }
}

extension Condition {
    /// Whether this condition holds for the given request.
    public func matches(_ ctx: RequestContext) -> Bool {
        switch self {
        case .domain(let v):
            return RuleMatcher.domainMatches(v, url: ctx.url)
        case .urlPrefix(let v):
            return RuleMatcher.prefixMatches(v, url: ctx.url)
        case .urlContains(let v):
            return ctx.url.absoluteString.localizedCaseInsensitiveContains(v)
        case .urlEquals(let v):
            return ctx.url.absoluteString == v
        case .urlRegex(let v):
            return RuleMatcher.regexMatches(v, url: ctx.url)
        case .sourceApp(let v):
            if v.contains(".") {
                return ctx.sourceBundleID?.caseInsensitiveCompare(v) == .orderedSame
            }
            return ctx.sourceAppName?.caseInsensitiveCompare(v) == .orderedSame
        }
    }
}

extension Rule {
    /// Whether this rule matches the request, combining conditions per `match`.
    public func matches(_ ctx: RequestContext) -> Bool {
        switch match {
        case .all:
            return conditions.allSatisfy { $0.matches(ctx) }
        case .any:
            return conditions.contains { $0.matches(ctx) }
        }
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

    /// The `browser` config value chosen for a request: first matching rule, else default.
    public func matchedBrowserValue(for ctx: RequestContext) -> String {
        for rule in config.rules where rule.matches(ctx) {
            return rule.browser
        }
        return config.defaultBrowser
    }

    /// Resolve the final target bundle id for a request.
    ///
    /// Candidate chain: matched rule's browser -> config `default` -> Safari.
    /// Each candidate must resolve to a bundle id, be installed, and not equal `selfBundleID`.
    public func resolveTargetBundleID(for ctx: RequestContext) -> String? {
        let candidates = [
            matchedBrowserValue(for: ctx),
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

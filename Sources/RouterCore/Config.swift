import Foundation
import Yams

/// A single routing rule. Exactly one of `domain` or `prefix` must be set.
public struct Rule: Equatable {
    public let domain: String?
    public let prefix: String?
    public let browser: String

    public init(domain: String? = nil, prefix: String? = nil, browser: String) {
        self.domain = domain
        self.prefix = prefix
        self.browser = browser
    }
}

/// The parsed configuration: a catch-all `default` browser plus ordered rules.
public struct Config: Equatable {
    public let defaultBrowser: String
    public let rules: [Rule]

    public init(defaultBrowser: String, rules: [Rule]) {
        self.defaultBrowser = defaultBrowser
        self.rules = rules
    }
}

/// Errors surfaced while loading or validating configuration.
public enum ConfigError: Error, Equatable, CustomStringConvertible {
    case malformedYAML(String)
    case missingDefault
    case ruleHasBothDomainAndPrefix(index: Int)
    case ruleHasNeitherDomainNorPrefix(index: Int)
    case ruleMissingBrowser(index: Int)

    public var description: String {
        switch self {
        case .malformedYAML(let msg):
            return "Malformed YAML: \(msg)"
        case .missingDefault:
            return "Config is missing a required `default` browser."
        case .ruleHasBothDomainAndPrefix(let i):
            return "Rule #\(i + 1) specifies both `domain` and `prefix`; exactly one is required."
        case .ruleHasNeitherDomainNorPrefix(let i):
            return "Rule #\(i + 1) specifies neither `domain` nor `prefix`; exactly one is required."
        case .ruleMissingBrowser(let i):
            return "Rule #\(i + 1) is missing a `browser`."
        }
    }
}

public enum ConfigLoader {
    /// Parse and validate YAML text into a `Config`.
    public static func parse(_ yaml: String) throws -> Config {
        let node: Any?
        do {
            node = try Yams.load(yaml: yaml)
        } catch {
            throw ConfigError.malformedYAML(String(describing: error))
        }

        guard let root = node as? [String: Any] else {
            throw ConfigError.malformedYAML("top level must be a mapping")
        }

        guard let defaultBrowser = (root["default"] as? String)?.trimmed, !defaultBrowser.isEmpty else {
            throw ConfigError.missingDefault
        }

        var rules: [Rule] = []
        // `rules:` with no items (or all-commented items) parses as YAML null — treat as empty.
        if let rawRules = root["rules"], !(rawRules is NSNull) {
            guard let list = rawRules as? [Any] else {
                throw ConfigError.malformedYAML("`rules` must be a list")
            }
            for (index, item) in list.enumerated() {
                guard let map = item as? [String: Any] else {
                    throw ConfigError.malformedYAML("rule #\(index + 1) must be a mapping")
                }
                let domain = (map["domain"] as? String)?.trimmed.nilIfEmpty
                let prefix = (map["prefix"] as? String)?.trimmed.nilIfEmpty
                let browser = (map["browser"] as? String)?.trimmed.nilIfEmpty

                switch (domain, prefix) {
                case (.some, .some):
                    throw ConfigError.ruleHasBothDomainAndPrefix(index: index)
                case (.none, .none):
                    throw ConfigError.ruleHasNeitherDomainNorPrefix(index: index)
                default:
                    break
                }
                guard let browser else {
                    throw ConfigError.ruleMissingBrowser(index: index)
                }
                rules.append(Rule(domain: domain, prefix: prefix, browser: browser))
            }
        }

        return Config(defaultBrowser: defaultBrowser, rules: rules)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

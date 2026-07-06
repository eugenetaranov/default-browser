import Foundation
import Yams

/// How a rule's conditions combine.
public enum MatchMode: String, Equatable {
    case all
    case any
}

/// A single condition within a rule. Each maps to one YAML key.
public enum Condition: Equatable {
    case domain(String)        // host == value or subdomain of it
    case urlPrefix(String)     // full URL string starts with value
    case urlContains(String)   // full URL string contains value
    case urlEquals(String)     // full URL string equals value
    case urlRegex(String)      // full URL string matches regex
    case sourceApp(String)     // opening app name (or bundle id if it has a dot)

    /// The YAML key used to serialize this condition.
    public var key: String {
        switch self {
        case .domain: return "domain"
        case .urlPrefix: return "prefix"
        case .urlContains: return "url_contains"
        case .urlEquals: return "url_equals"
        case .urlRegex: return "url_regex"
        case .sourceApp: return "source_app"
        }
    }

    public var value: String {
        switch self {
        case .domain(let v), .urlPrefix(let v), .urlContains(let v),
             .urlEquals(let v), .urlRegex(let v), .sourceApp(let v):
            return v
        }
    }

    /// Build a condition from a YAML key/value, or nil if the key is unknown.
    static func make(key: String, value: String) -> Condition? {
        switch key {
        case "domain": return .domain(value)
        case "prefix": return .urlPrefix(value)
        case "url_contains": return .urlContains(value)
        case "url_equals": return .urlEquals(value)
        case "url_regex": return .urlRegex(value)
        case "source_app": return .sourceApp(value)
        default: return nil
        }
    }
}

/// A routing rule: when its conditions match (per `match`), route to `browser`.
public struct Rule: Equatable {
    public let match: MatchMode
    public let conditions: [Condition]
    public let browser: String

    public init(match: MatchMode = .all, conditions: [Condition], browser: String) {
        self.match = match
        self.conditions = conditions
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
    case ruleMissingBrowser(index: Int)
    case ruleHasNoConditions(index: Int)
    case ruleInvalidMatch(index: Int, value: String)
    case unknownConditionKey(index: Int, key: String)
    case conditionNotSingleKey(index: Int)

    public var description: String {
        switch self {
        case .malformedYAML(let msg):
            return "Malformed YAML: \(msg)"
        case .missingDefault:
            return "Config is missing a required `default` browser."
        case .ruleMissingBrowser(let i):
            return "Rule #\(i + 1) is missing a `browser`."
        case .ruleHasNoConditions(let i):
            return "Rule #\(i + 1) has no conditions."
        case .ruleInvalidMatch(let i, let v):
            return "Rule #\(i + 1) has invalid `match: \(v)` (use `all` or `any`)."
        case .unknownConditionKey(let i, let k):
            return "Rule #\(i + 1) has an unknown condition `\(k)`."
        case .conditionNotSingleKey(let i):
            return "Rule #\(i + 1) has a condition that isn't a single key/value pair."
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
                rules.append(try parseRule(map, index: index))
            }
        }

        return Config(defaultBrowser: defaultBrowser, rules: rules)
    }

    private static func parseRule(_ map: [String: Any], index: Int) throws -> Rule {
        guard let browser = (map["browser"] as? String)?.trimmed.nilIfEmpty else {
            throw ConfigError.ruleMissingBrowser(index: index)
        }

        // New schema: explicit `conditions:` list (+ optional `match:`).
        if let rawConditions = map["conditions"] {
            guard let list = rawConditions as? [Any] else {
                throw ConfigError.malformedYAML("rule #\(index + 1) `conditions` must be a list")
            }
            let match = try parseMatch(map["match"], index: index)
            var conditions: [Condition] = []
            for item in list {
                guard let cmap = item as? [String: Any], cmap.count == 1,
                      let (key, rawValue) = cmap.first else {
                    throw ConfigError.conditionNotSingleKey(index: index)
                }
                let value = String(describing: rawValue).trimmed
                guard let condition = Condition.make(key: key, value: value) else {
                    throw ConfigError.unknownConditionKey(index: index, key: key)
                }
                conditions.append(condition)
            }
            guard !conditions.isEmpty else {
                throw ConfigError.ruleHasNoConditions(index: index)
            }
            return Rule(match: match, conditions: conditions, browser: browser)
        }

        // Legacy flat schema: a single inline condition key alongside `browser`.
        for key in ["domain", "prefix", "url_contains", "url_equals", "url_regex", "source_app"] {
            if let value = (map[key] as? String)?.trimmed.nilIfEmpty {
                return Rule(match: .all, conditions: [Condition.make(key: key, value: value)!], browser: browser)
            }
        }
        throw ConfigError.ruleHasNoConditions(index: index)
    }

    private static func parseMatch(_ raw: Any?, index: Int) throws -> MatchMode {
        guard let raw else { return .all }
        guard let str = (raw as? String)?.trimmed.lowercased(), let mode = MatchMode(rawValue: str) else {
            throw ConfigError.ruleInvalidMatch(index: index, value: String(describing: raw))
        }
        return mode
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

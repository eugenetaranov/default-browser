import Foundation
import Yams

/// Serializes a `Config` back to YAML using the new rule schema, with stable key order.
/// Note: this emits a normalized document — comments in the original file are not preserved.
public enum ConfigSerializer {
    public static func dump(_ config: Config) throws -> String {
        var rootPairs: [(Node, Node)] = [
            (Node("default"), Node(config.defaultBrowser)),
        ]

        if !config.rules.isEmpty {
            let ruleNodes: [Node] = config.rules.map { rule in
                let conditionNodes: [Node] = rule.conditions.map { c in
                    Node.mapping(Node.Mapping([(Node(c.key), Node(c.value))]))
                }
                let pairs: [(Node, Node)] = [
                    (Node("match"), Node(rule.match.rawValue)),
                    (Node("conditions"), Node.sequence(Node.Sequence(conditionNodes))),
                    (Node("browser"), Node(rule.browser)),
                ]
                return Node.mapping(Node.Mapping(pairs))
            }
            rootPairs.append((Node("rules"), Node.sequence(Node.Sequence(ruleNodes))))
        }

        let root = Node.mapping(Node.Mapping(rootPairs))
        return try Yams.serialize(node: root)
    }
}

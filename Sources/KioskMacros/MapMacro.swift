import SwiftSyntax
import SwiftSyntaxMacros

/// `@Map` generates `toMap() -> [String: Any]` and `init(map:)`.
public struct MapMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let properties = storedProperties(of: declaration)
        guard !properties.isEmpty else { return [] }

        // toMap
        let entries = properties.map { "    \"\($0.name)\": \($0.name) as Any" }.joined(separator: ",\n")
        let toMap: DeclSyntax = """
        public func toMap() -> [Swift.String: Any] {
            [\n\(raw: entries)\n    ]
        }
        """

        // init(map:)
        let assigns = properties.map { prop in
            "self.\(prop.name) = map[\"\(prop.name)\"] as? \(prop.type) ?? \(prop.defaultLiteral)"
        }.joined(separator: "\n    ")
        let fromMap: DeclSyntax = """
        public init(map: [Swift.String: Any]) {
            \(raw: assigns)
        }
        """

        return [toMap, fromMap]
    }
}

private extension StoredProperty {
    var defaultLiteral: String {
        if type.hasSuffix("?") { return "nil" }
        if type == "Double" || type == "Float" || type == "CGFloat" { return "0" }
        if type == "Int" { return "0" }
        if type == "Bool" { return "false" }
        if type == "String" || type == "Swift.String" { return "\"\"" }
        return "\(type)()"
    }
}

import SwiftSyntax
import SwiftSyntaxMacros

/// `@Json` generates `toJson() -> String` and `init(json:)`.
/// Relies on `@Map` being present (uses toMap/init(map:) internally).
public struct JsonMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let toJson: DeclSyntax = """
        public func toJson() -> Swift.String {
            guard let data = try? JSONSerialization.data(withJSONObject: toMap(), options: [.sortedKeys]),
                  let str = Swift.String(data: data, encoding: .utf8) else { return "{}" }
            return str
        }
        """

        let fromJson: DeclSyntax = """
        public init?(json: Swift.String) {
            guard let data = json.data(using: .utf8),
                  let map = try? JSONSerialization.jsonObject(with: data) as? [Swift.String: Any] else { return nil }
            self.init(map: map)
        }
        """

        return [toJson, fromJson]
    }
}

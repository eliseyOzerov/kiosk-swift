import SwiftSyntax
import SwiftSyntaxMacros

/// `@String` generates a `description` property listing all stored properties.
public struct StringMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let properties = storedProperties(of: declaration)
        let name = typeName(of: declaration)

        let labels = properties.map { "\($0.name): \\(\($0.name))" }.joined(separator: ", ")

        let decl: DeclSyntax = """
        public var description: Swift.String {
            "\(raw: name)(\(raw: labels))"
        }
        """

        return [decl]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: DeclSyntax = "extension \(type.trimmed): CustomStringConvertible {}"
        return [ext.cast(ExtensionDeclSyntax.self)]
    }
}

import SwiftSyntax
import SwiftSyntaxMacros

/// `@Data` = `@Init` + `@Copy` + `@Merge` — generates memberwise init,
/// static per-property factories, fluent copy methods, and merge.
public struct DataMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let initDecls = try InitMacro.expansion(
            of: node, providingMembersOf: declaration, conformingTo: protocols, in: context)
        let copyDecls = try CopyMacro.expansion(
            of: node, providingMembersOf: declaration, conformingTo: protocols, in: context)
        let mergeDecls = try MergeMacro.expansion(
            of: node, providingMembersOf: declaration, conformingTo: protocols, in: context)
        return initDecls + copyDecls + mergeDecls
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        return try MergeMacro.expansion(
            of: node, attachedTo: declaration, providingExtensionsOf: type,
            conformingTo: protocols, in: context)
    }
}

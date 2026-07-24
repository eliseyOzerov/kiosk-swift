import SwiftSyntax
import SwiftSyntaxMacros

/// `@Style` = `@Data` + `@Lerp`.
public struct StyleMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let dataDecls = try DataMacro.expansion(
            of: node, providingMembersOf: declaration, conformingTo: protocols, in: context)
        let lerpDecls = try LerpMacro.expansion(
            of: node, providingMembersOf: declaration, conformingTo: protocols, in: context)
        return dataDecls + lerpDecls
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let mergeExt = try MergeMacro.expansion(
            of: node, attachedTo: declaration, providingExtensionsOf: type,
            conformingTo: protocols, in: context)
        let lerpExt = try LerpMacro.expansion(
            of: node, attachedTo: declaration, providingExtensionsOf: type,
            conformingTo: protocols, in: context)
        return mergeExt + lerpExt
    }
}

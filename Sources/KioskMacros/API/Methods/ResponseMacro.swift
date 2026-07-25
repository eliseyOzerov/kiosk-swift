import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates scoped `@Status(status)` error body marker attributes.
public struct StatusMacro: MemberMacro, ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard declaration.as(StructDeclSyntax.self) != nil else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "@Status can only be attached to status error body structs.",
            id: "status-macro-requires-struct"
          )
        )
      )
      return []
    }

    guard StatusAttribute(node) != nil else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "Expected @Status(.status).",
            id: "invalid-status-attribute"
          )
        )
      )
      return []
    }

    return try EndpointContractWire.generatedMembers(
      of: node,
      providingMembersOf: declaration,
      conformingTo: protocols,
      in: context
    )
  }

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    try EndpointContractWire.generatedExtensions(
      of: node,
      attachedTo: declaration,
      providingExtensionsOf: type,
      conformingTo: protocols,
      in: context
    )
  }
}

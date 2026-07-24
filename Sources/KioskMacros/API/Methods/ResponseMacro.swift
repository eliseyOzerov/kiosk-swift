import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates nested endpoint `@Response(status)` contract marker attributes.
public struct ResponseMacro: MemberMacro, ExtensionMacro {
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
            "@Response can only be attached to response body structs.",
            id: "response-macro-requires-struct"
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
            "Expected @Response(.status).",
            id: "invalid-response-attribute"
          )
        )
      )
      return []
    }

    return try EndpointContractSerialization.generatedMembers(
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
    try EndpointContractSerialization.generatedExtensions(
      of: node,
      attachedTo: declaration,
      providingExtensionsOf: type,
      conformingTo: protocols,
      in: context
    )
  }
}

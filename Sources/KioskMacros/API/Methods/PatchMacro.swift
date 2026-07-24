import SwiftSyntax
import SwiftSyntaxMacros

public struct PatchMacro: BodyMacro, MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    try HTTPMethodBody.expand(.patch, of: node, providingBodyFor: declaration)
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try HTTPMethodBody.expand(.patch, of: node, providingMembersOf: declaration, in: context)
  }
}

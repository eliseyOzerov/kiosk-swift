import SwiftSyntax
import SwiftSyntaxMacros

public struct GetMacro: BodyMacro, MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    try HTTPMethodBody.expand(.get, of: node, providingBodyFor: declaration)
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try HTTPMethodBody.expand(.get, of: node, providingMembersOf: declaration, in: context)
  }
}

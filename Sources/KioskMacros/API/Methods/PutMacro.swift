import SwiftSyntax
import SwiftSyntaxMacros

public struct PutMacro: BodyMacro, MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    try HTTPMethodBody.expand(.put, of: node, providingBodyFor: declaration)
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try HTTPMethodBody.expand(.put, of: node, providingMembersOf: declaration, in: context)
  }
}

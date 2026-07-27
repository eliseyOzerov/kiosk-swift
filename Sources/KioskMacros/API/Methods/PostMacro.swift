import SwiftSyntax
import SwiftSyntaxMacros

public struct PostMacro: BodyMacro, MemberMacro, PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    try HTTPMethodBody.expand(.post, of: node, providingBodyFor: declaration)
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try HTTPMethodBody.expand(.post, of: node, providingMembersOf: declaration, in: context)
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try HTTPMethodBody.expand(.post, of: node, providingPeersOf: declaration, in: context)
  }
}

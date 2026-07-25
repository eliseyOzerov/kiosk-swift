import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct WireMacro: MemberMacro, ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let model = WireModel(declaration, context: context) else {
      return []
    }

    return model.generatedMembers()
  }

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let genericWhereClause = declaration.genericParameterNames
      .map { "\($0): WireCodable" }
      .joined(separator: ", ")
    let whereClause = genericWhereClause.isEmpty ? "" : " where \(genericWhereClause)"

    return [
      try ExtensionDeclSyntax(
        "extension \(raw: type.trimmedDescription): WireCodable\(raw: whereClause) {}")
    ]
  }
}

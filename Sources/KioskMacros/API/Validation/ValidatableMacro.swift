import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ValidatableMacro: MemberMacro, ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let model = ValidatableModel(declaration, context: context) else {
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
    [
      try ExtensionDeclSyntax("extension \(raw: type.trimmedDescription): Validatable {}")
    ]
  }
}

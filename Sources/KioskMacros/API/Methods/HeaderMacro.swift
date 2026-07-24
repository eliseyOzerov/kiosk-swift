import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates endpoint `@Header(name, Type.self)` marker attributes.
public struct HeaderMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let declaration = declaration.as(StructDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "@Header can only be attached to endpoint structs.",
            id: "header-macro-requires-struct"
          )
        )
      )
      return []
    }

    guard declaration.hasMethodAttribute else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "@Header can only be used with @Get, @Post, @Put, @Patch, or @Delete.",
            id: "header-macro-requires-method"
          )
        )
      )
      return []
    }

    guard HeaderAttribute(node) != nil else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "Expected @Header(.name, Type.self) or @Header(\"Name\", Type.self).",
            id: "invalid-header-attribute"
          )
        )
      )
      return []
    }

    return []
  }
}

private extension StructDeclSyntax {
  var hasMethodAttribute: Bool {
    attributes.contains { element in
      guard let attribute = element.as(AttributeSyntax.self) else {
        return false
      }

      return ["Get", "Post", "Put", "Patch", "Delete"]
        .contains(attribute.attributeName.trimmedDescription)
    }
  }
}

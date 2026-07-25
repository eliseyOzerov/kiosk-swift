import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates parameter `@Header(name, Type.self)` and default `@Header(name, value)` attributes.
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
            "@Header can only be attached to API, path, or endpoint structs.",
            id: "header-macro-requires-struct"
          )
        )
      )
      return []
    }

    guard declaration.hasRouteOrMethodAttribute else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "@Header can only be used with @Api, @Path, @Get, @Post, @Put, @Patch, or @Delete.",
            id: "header-macro-requires-route-or-method"
          )
        )
      )
      return []
    }

    if declaration.hasMethodAttribute {
      guard HeaderAttribute(node) != nil || StaticHeaderAttribute(node) != nil else {
        context.diagnose(
          Diagnostic(
            node: Syntax(node),
            message: ApiUtilsMacroDiagnostic(
              "Expected @Header(.name, Type.self), @Header(\"Name\", Type.self), @Header(.name, value), or @Header(\"Name\", value).",
              id: "invalid-header-attribute"
            )
          )
        )
        return []
      }
    } else {
      guard StaticHeaderAttribute(node) != nil else {
        context.diagnose(
          Diagnostic(
            node: Syntax(node),
            message: ApiUtilsMacroDiagnostic(
              "Expected @Header(.name, value) or @Header(\"Name\", value) when applying @Header to @Api or @Path.",
              id: "invalid-scoped-header-attribute"
            )
          )
        )
        return []
      }
    }

    return []
  }
}

private extension StructDeclSyntax {
  var hasRouteOrMethodAttribute: Bool {
    attributes.contains { element in
      guard let attribute = element.as(AttributeSyntax.self) else {
        return false
      }

      return ["Api", "Path", "Get", "Post", "Put", "Patch", "Delete"]
        .contains(attribute.attributeName.trimmedDescription)
    }
  }

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

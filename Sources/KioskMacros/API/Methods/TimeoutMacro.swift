import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates scoped `@Timeout(request:resource:)` attributes.
public struct TimeoutMacro: MemberMacro {
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
            "@Timeout can only be attached to API, path, or endpoint structs.",
            id: "timeout-macro-requires-struct"
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
            "@Timeout can only be used with @Api, @Path, @Get, @Post, @Put, @Patch, or @Delete.",
            id: "timeout-macro-requires-route-or-method"
          )
        )
      )
      return []
    }

    guard TimeoutAttribute(node) != nil else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "Expected @Timeout(request: seconds, resource: seconds).",
            id: "invalid-timeout-attribute"
          )
        )
      )
      return []
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
}

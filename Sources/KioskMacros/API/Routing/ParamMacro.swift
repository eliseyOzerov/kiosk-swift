import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct ParamMacro: MemberMacro {
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
            "@Param can only be attached to route or endpoint structs.",
            id: "param-macro-requires-struct"
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
            "@Param can only be used with @Path, @Api, @Get, @Post, @Put, @Patch, or @Delete.",
            id: "param-macro-requires-route-or-method"
          )
        )
      )
      return []
    }

    guard LabeledTypeAttribute(node) != nil else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "Expected @Param(\"label\", Type.self).",
            id: "invalid-param-attribute"
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

      return ["Path", "Api", "Get", "Post", "Put", "Patch", "Delete"]
        .contains(attribute.attributeName.trimmedDescription)
    }
  }
}

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates endpoint and path `@Wrap` attributes.
public struct WrapMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    WrapperPolicyMacro.validate(
      node,
      declaration: declaration,
      context: context,
      attributeName: "Wrap"
    )
  }
}

/// Validates endpoint and path `@Unwrap` attributes.
public struct UnwrapMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    WrapperPolicyMacro.validate(
      node,
      declaration: declaration,
      context: context,
      attributeName: "Unwrap"
    )
  }
}

/// Shared validation for endpoint and path wrapper policy marker macros.
private enum WrapperPolicyMacro {
  static func validate(
    _ node: AttributeSyntax,
    declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext,
    attributeName: String
  ) -> [DeclSyntax] {
    guard let declaration = declaration.as(StructDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "@\(attributeName) can only be attached to API path or endpoint structs.",
            id: "\(attributeName.lowercased())-macro-requires-struct"
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
            "@\(attributeName) can only be used with @Api, @Path, @Get, @Post, @Put, @Patch, or @Delete.",
            id: "\(attributeName.lowercased())-macro-requires-route-or-method"
          )
        )
      )
      return []
    }

    guard WrapperAttribute(node) != nil else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "Expected @\(attributeName)(.key).",
            id: "invalid-\(attributeName.lowercased())-attribute"
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

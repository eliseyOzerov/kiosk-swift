import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates endpoint `@Content` attributes.
public struct ContentMacro: MemberMacro {
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
            "@Content can only be attached to endpoint structs.",
            id: "content-macro-requires-struct"
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
            "@Content can only be used with @Get, @Post, @Put, @Patch, or @Delete.",
            id: "content-macro-requires-route-or-method"
          )
        )
      )
      return []
    }

    guard ContentAttribute(node) != nil else {
      context.diagnose(
        Diagnostic(
            node: Syntax(node),
            message: ApiUtilsMacroDiagnostic(
              "Expected @Content(Value.self). Use @Header(.contentType, .type) for Content-Type.",
              id: "invalid-content-attribute"
          )
        )
      )
      return []
    }

    return []
  }
}

/// Validates content property `@Part` multipart markers.
public struct PartMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard declaration.as(VariableDeclSyntax.self) != nil else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "@Part can only be attached to stored content properties.",
            id: "part-macro-requires-property"
          )
        )
      )
      return []
    }

    guard AttributeArgument.secondArgument(in: node) == nil else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "Expected @Part or @Part(\"name\").",
            id: "invalid-part-attribute"
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

      return ["Path", "Route", "Api", "Get", "Post", "Put", "Patch", "Delete"]
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

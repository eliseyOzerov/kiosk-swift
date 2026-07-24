import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates endpoint and path `@Content` attributes.
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
            "@Content can only be attached to API path or endpoint structs.",
            id: "content-macro-requires-struct"
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
            "@Content can only be used with @Api, @Path, @Get, @Post, @Put, @Patch, or @Delete.",
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
            "Expected @Content(.type) or @Content(.type, Value.self).",
            id: "invalid-content-attribute"
          )
        )
      )
      return []
    }

    return []
  }
}

/// Validates endpoint and path `@Accept` attributes.
public struct AcceptMacro: MemberMacro {
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
            "@Accept can only be attached to API path or endpoint structs.",
            id: "accept-macro-requires-struct"
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
            "@Accept can only be used with @Api, @Path, @Get, @Post, @Put, @Patch, or @Delete.",
            id: "accept-macro-requires-route-or-method"
          )
        )
      )
      return []
    }

    guard ContentAttribute(node)?.valueType == nil else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "@Accept only takes a content type.",
            id: "invalid-accept-attribute"
          )
        )
      )
      return []
    }

    return []
  }
}

/// Validates endpoint `@Field("label", Type.self)` content fields.
public struct APIFieldMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try EndpointContentFieldMacro.validate(
      node,
      declaration: declaration,
      context: context,
      attributeName: "Field"
    )
  }
}

/// Validates endpoint `@Part("label", Type.self)` multipart content parts.
public struct PartMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try EndpointContentFieldMacro.validate(
      node,
      declaration: declaration,
      context: context,
      attributeName: "Part"
    )
  }
}

private enum EndpointContentFieldMacro {
  static func validate(
    _ node: AttributeSyntax,
    declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext,
    attributeName: String
  ) throws -> [DeclSyntax] {
    guard let declaration = declaration.as(StructDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "@\(attributeName) can only be attached to endpoint structs.",
            id: "\(attributeName.lowercased())-macro-requires-struct"
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
            "@\(attributeName) can only be used with @Get, @Post, @Put, @Patch, or @Delete.",
            id: "\(attributeName.lowercased())-macro-requires-method"
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
            "Expected @\(attributeName)(\"label\", Type.self).",
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

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates endpoint `@Query("label", Type.self)` and nested `@Query` marker attributes.
public struct QueryMacro: MemberMacro, PeerMacro {
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
            "@Query can only be attached to endpoint structs.",
            id: "query-macro-requires-struct"
          )
        )
      )
      return []
    }

    if LabeledTypeAttribute(node) == nil,
      !node.hasArguments
    {
      guard !declaration.hasMethodAttribute else {
        context.diagnose(
          Diagnostic(
            node: Syntax(node),
            message: ApiUtilsMacroDiagnostic(
              "Expected @Query(\"label\", Type.self) on endpoint structs.",
              id: "invalid-endpoint-query-marker"
            )
          )
        )
        return []
      }

      return []
    }

    guard declaration.hasMethodAttribute else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "@Query can only be used with @Get, @Post, @Put, @Patch, or @Delete.",
            id: "query-macro-requires-method"
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
            "Expected @Query(\"label\", Type.self).",
            id: "invalid-query-attribute"
          )
        )
      )
      return []
    }

    return []
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    if let declaration = declaration.as(StructDeclSyntax.self),
      declaration.hasMethodAttribute
    {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "Expected @Query(\"label\", Type.self) on endpoint structs.",
            id: "invalid-endpoint-query-marker"
          )
        )
      )
      return []
    }

    guard declaration.as(TypeAliasDeclSyntax.self) != nil else {
      return []
    }

    guard !node.hasArguments else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "@Query on a typealias does not take arguments.",
            id: "invalid-query-typealias-marker"
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

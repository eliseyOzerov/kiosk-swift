import SwiftSyntax
import SwiftSyntaxMacros

/// `@Mergeable` generates a `merge(_ other:)` method:
/// `self.property ?? other.property` for each stored property.
///
///     @Mergeable
///     struct TextStyle {
///         var font: Font?
///         var color: Color?
///     }
///
/// Expands to:
///
///     extension TextStyle: Mergeable {
///         func merge(_ other: TextStyle) -> TextStyle {
///             TextStyle(font: font ?? other.font, color: color ?? other.color)
///         }
///     }
///
/// Properties that are themselves `Mergeable` use `.merge()` instead of `??`:
/// if `self.prop` is non-nil, it merges with `other.prop`; if nil, falls through.
/// Mark these with `@MergeNested` or by conforming the type to `Mergeable`.
public struct MergeMacro: MemberMacro, ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let properties = storedProperties(of: declaration)
    let name = typeName(of: declaration)

    let assignments = properties.map { prop in
      if prop.isExpanded {
        if prop.isOptional {
          "\(prop.name): \(prop.name)?.merge(other.\(prop.name)) ?? other.\(prop.name)"
        } else {
          "\(prop.name): \(prop.name).merge(other.\(prop.name))"
        }
      } else {
        "\(prop.name): \(prop.name) ?? other.\(prop.name)"
      }
    }.joined(separator: ", ")
    let access = accessModifier(of: declaration)
    let accessPrefix = access.isEmpty ? "" : "\(access) "

    let method: DeclSyntax = """
      \(raw: accessPrefix)func merge(_ other: \(raw: name)) -> \(raw: name) {
          \(raw: name)(\(raw: assignments))
      }
      """

    return [method]
  }

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let ext: DeclSyntax = "extension \(type.trimmed): Mergeable {}"
    return [ext.cast(ExtensionDeclSyntax.self)]
  }
}

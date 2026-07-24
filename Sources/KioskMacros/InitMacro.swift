import SwiftSyntax
import SwiftSyntaxMacros

/// `@Initializable` generates:
/// 1. A public memberwise initializer (optionals default to nil)
/// 2. Static factory methods per property for single-field construction
///
///     @Initializable
///     struct TextStyle {
///         var font: Font?
///         var color: Color?
///     }
///
/// Expands to:
///
///     public init(font: Font? = nil, color: Color? = nil) { ... }
///     public static func font(_ value: Font?) -> TextStyle { TextStyle(font: value) }
///     public static func color(_ value: Color?) -> TextStyle { TextStyle(color: value) }
public struct InitMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let properties = initProperties(of: declaration)
        let name = typeName(of: declaration)
        guard !properties.isEmpty else { return [] }

        // Memberwise init
        let params = properties.map { prop in
            if let defaultValue = prop.defaultValue {
                return "\(prop.name): \(prop.type) = \(defaultValue)"
            } else if prop.isOptional {
                return "\(prop.name): \(prop.type) = nil"
            } else {
                return "\(prop.name): \(prop.type)"
            }
        }.joined(separator: ", ")

        let assignments = properties.map { "self.\($0.name) = \($0.name)" }.joined(separator: "; ")

        var decls: [DeclSyntax] = [
            """
            public init(\(raw: params)) {
                \(raw: assignments)
            }
            """
        ]

        // Static factory per property — only when all OTHER properties have defaults
        let allHaveDefaults = properties.allSatisfy { $0.isOptional || $0.defaultValue != nil }
        if allHaveDefaults {
            for prop in properties {
                decls.append(
                    """
                    public static func \(raw: prop.name)(_ value: \(raw: prop.type)) -> \(raw: name) { \(raw: name)(\(raw: prop.name): value) }
                    """
                )
            }
        }

        return decls
    }
}

// MARK: - Helpers

private struct InitProperty {
    let name: String
    let type: String
    let isOptional: Bool
    let defaultValue: String?
}

private func initProperties(of declaration: some DeclGroupSyntax) -> [InitProperty] {
    declaration.memberBlock.members.compactMap { member -> InitProperty? in
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              varDecl.bindingSpecifier.text == "var" else { return nil }

        guard let binding = varDecl.bindings.first else { return nil }

        // Skip computed properties
        if let accessors = binding.accessorBlock {
            switch accessors.accessors {
            case .getter:
                return nil
            case .accessors(let list):
                let kinds = list.map { $0.accessorSpecifier.text }
                if kinds.contains("get") || kinds.contains("set") { return nil }
            }
        }

        guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              let typeAnnotation = binding.typeAnnotation?.type else {
            return nil
        }

        let type = typeAnnotation.trimmedDescription
        let isOptional = typeAnnotation.is(OptionalTypeSyntax.self)
            || typeAnnotation.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
        let defaultValue = binding.initializer?.value.trimmedDescription

        return InitProperty(name: name, type: type, isOptional: isOptional, defaultValue: defaultValue)
    }
}

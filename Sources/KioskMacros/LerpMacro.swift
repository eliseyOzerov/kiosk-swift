import SwiftSyntax
import SwiftSyntaxMacros

/// `@Lerp` generates `lerp(to:t:)`. Fields marked `@Snap` snap (t < 0.5);
/// all other fields call `.lerp(to:t:)`. Optional fields use lerpOptional.
public struct LerpMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let properties = lerpProperties(of: declaration)
        let name = typeName(of: declaration)
        guard !properties.isEmpty else { return [] }

        let assignments = properties.map { prop in
            if prop.snap {
                return "\(prop.name): t < 0.5 ? \(prop.name) : other.\(prop.name)"
            } else if prop.isOptional {
                return "\(prop.name): lerpOptional(\(prop.name), other.\(prop.name), t: t)"
            } else {
                return "\(prop.name): \(prop.name).lerp(to: other.\(prop.name), t: t)"
            }
        }.joined(separator: ", ")

        let method: DeclSyntax = """
        public func lerp(to other: \(raw: name), t: Double) -> \(raw: name) {
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
        let ext: DeclSyntax = "extension \(type.trimmed): Lerpable {}"
        return [ext.cast(ExtensionDeclSyntax.self)]
    }
}

// MARK: - Helpers

private struct LerpProperty {
    let name: String
    let type: String
    let isOptional: Bool
    let snap: Bool
}

private func lerpProperties(of declaration: some DeclGroupSyntax) -> [LerpProperty] {
    declaration.memberBlock.members.compactMap { member -> LerpProperty? in
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

        // Check for @Snap attribute
        let snap = varDecl.attributes.contains { attr in
            attr.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "Snap"
        }

        return LerpProperty(name: name, type: type, isOptional: isOptional, snap: snap)
    }
}

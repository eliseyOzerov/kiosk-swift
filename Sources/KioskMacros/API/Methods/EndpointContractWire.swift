import SwiftSyntax
import SwiftSyntaxMacros

/// Shared wire synthesis for endpoint contract marker macros.
enum EndpointContractWire {
	static func generatedMembers(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		guard declaration.attribute(named: "Wire") == nil else {
			return []
		}

		return try WireMacro.expansion(
			of: node,
			providingMembersOf: declaration,
			conformingTo: protocols,
			in: context
		)
	}

	static func generatedExtensions(
		of node: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [ExtensionDeclSyntax] {
		guard declaration.attribute(named: "Wire") == nil else {
			return []
		}

		return try WireMacro.expansion(
			of: node,
			attachedTo: declaration,
			providingExtensionsOf: type,
			conformingTo: protocols,
			in: context
		)
	}
}

import SwiftSyntax
import SwiftSyntaxMacros

/// Field marker — no code generation. Read by `@Lerp` to snap instead of interpolate.
public struct SnapMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // No-op — this is just a marker attribute read by LerpMacro.
        return []
    }
}

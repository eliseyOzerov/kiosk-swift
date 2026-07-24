import SwiftSyntax
import SwiftSyntaxMacros

/// `@Erased` generates an `AnyX` type-erased wrapper for a protocol.
///
///     @Erased
///     protocol Shape: Equatable, Lerpable {
///         func path(in rect: Rect) -> Path
///     }
///
/// Generates `AnyShape` with a box pattern that preserves Equatable
/// and Lerpable through the concrete type. Box classes are nested inside
/// the struct so only one top-level name (`AnyX`) is introduced.
///
/// When the protocol inherits Lerpable, the generated `AnyX.lerp(to:t:)`
/// delegates to concrete-type lerp when types match. When they don't,
/// it calls `AnyX._lerpFallback(_:_:t:)` which defaults to a snap at
/// t=0.5. Override this static method in an extension for custom
/// cross-type interpolation (e.g. path morphing for shapes).
///
/// Add manually after the protocol:
///   - `extension AnyShape: Shape {}`
///   - `extension Shape { var erased: AnyShape { AnyShape(self) } }`
public struct ErasedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
            return []
        }

        let protoName = proto.name.text
        let anyName = "Any\(protoName)"

        // Collect protocol methods (skip isEqual/lerp — handled by the box)
        let methods = proto.memberBlock.members.compactMap { member -> ProtocolMethod? in
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { return nil }
            let name = funcDecl.name.text
            if name == "isEqual" || name == "lerp" { return nil }
            let sig = funcDecl.signature
            let params = sig.parameterClause.parameters.map { p in
                let label = p.firstName.text
                let paramName = p.secondName?.text ?? label
                let type = p.type.trimmedDescription
                let labelPart = label == "_" ? "_ " : (label == paramName ? "" : "\(label) ")
                return "\(labelPart)\(paramName): \(type)"
            }.joined(separator: ", ")
            let returnType = sig.returnClause?.type.trimmedDescription
            return ProtocolMethod(name: name, params: params, returnType: returnType)
        }

        // Check which protocols are inherited
        let inherited = proto.inheritanceClause?.inheritedTypes.map { $0.type.trimmedDescription } ?? []
        let hasEquatable = inherited.contains("Equatable")
        let hasLerpable = inherited.contains("Lerpable")

        // --- Conformances ---
        var anyConformances = ""
        if hasEquatable { anyConformances += ": Equatable" }
        if hasLerpable { anyConformances += anyConformances.isEmpty ? ": Lerpable" : ", Lerpable" }

        // --- Forwarding methods ---
        let forwardMethods = methods.map { m in
            let call = "box.\(m.name)(\(m.callArgs))"
            let ret = m.returnType.map { " -> \($0)" } ?? ""
            return "    public func \(m.name)(\(m.params))\(ret) { \(call) }"
        }.joined(separator: "\n")

        // --- Box base class methods ---
        let boxMethods = methods.map { m in
            let ret = m.returnType.map { " -> \($0)" } ?? ""
            return "        func \(m.name)(\(m.params))\(ret) { fatalError() }"
        }.joined(separator: "\n")

        var boxExtraMethods = ""
        if hasEquatable {
            boxExtraMethods += "        func isEqual(to other: Box) -> Bool { fatalError() }\n"
        }
        if hasLerpable {
            boxExtraMethods += "        func canLerp(to other: Box) -> Bool { fatalError() }\n"
            boxExtraMethods += "        func lerp(to other: Box, t: Double) -> Box { fatalError() }\n"
        }

        // --- Concrete box overrides ---
        let concreteOverrides = methods.map { m in
            let ret = m.returnType.map { " -> \($0)" } ?? ""
            let call = "value.\(m.name)(\(m.callArgs))"
            return "        override func \(m.name)(\(m.params))\(ret) { \(call) }"
        }.joined(separator: "\n")

        var concreteExtraOverrides = ""
        if hasEquatable {
            concreteExtraOverrides += """
                    override func isEqual(to other: Box) -> Bool {
                        guard let other = other as? Concrete<T> else { return false }
                        return value == other.value
                    }

            """
        }
        if hasLerpable {
            concreteExtraOverrides += """
                    override func canLerp(to other: Box) -> Bool { other is Concrete<T> }
                    override func lerp(to other: Box, t: Double) -> Box {
                        guard let other = other as? Concrete<T> else { return t < 0.5 ? self : other }
                        let result: T = value.lerp(to: other.value, t: t)
                        return Concrete(result)
                    }

            """
        }

        // --- Equatable/Lerpable members ---
        var eqLerpMembers = ""
        if hasEquatable {
            eqLerpMembers += """

                public static func ==(lhs: \(anyName), rhs: \(anyName)) -> Bool {
                    lhs.box.isEqual(to: rhs.box)
                }
            """
        }
        if hasLerpable {
            eqLerpMembers += """

                public func lerp(to other: \(anyName), t: Double) -> \(anyName) {
                    if box.canLerp(to: other.box) {
                        return \(anyName)(box: box.lerp(to: other.box, t: t))
                    }
                    return _\(anyName)LerpFallback(self, other, t: t)
                }

                fileprivate init(box: Box) { self.box = box }
            """
        }

        // --- Single struct with nested classes ---
        let anyStruct: DeclSyntax = """
        public struct \(raw: anyName)\(raw: anyConformances) {
            fileprivate let box: Box

            public init<T: \(raw: protoName)>(_ value: T) {
                if let any = value as? \(raw: anyName) { box = any.box }
                else { box = Concrete(value) }
            }

        \(raw: forwardMethods)
        \(raw: eqLerpMembers)

            fileprivate class Box {
        \(raw: boxMethods)
        \(raw: boxExtraMethods)    }

            fileprivate final class Concrete<T: \(raw: protoName)>: Box {
                let value: T
                init(_ value: T) { self.value = value }
        \(raw: concreteOverrides)
        \(raw: concreteExtraOverrides)    }
        }
        """

        return [anyStruct]
    }
}

// MARK: - Helpers

private extension String {
    func trim() -> String {
        var s = self
        while s.first == " " || s.first == "\t" || s.first == "\n" { s.removeFirst() }
        while s.last == " " || s.last == "\t" || s.last == "\n" { s.removeLast() }
        return s
    }
}

private struct ProtocolMethod {
    let name: String
    let params: String
    let returnType: String?

    var callArgs: String {
        let parts = params.split(separator: ",").map { String($0).trim() }
        return parts.map { part in
            let colonIdx = part.firstIndex(of: ":")!
            let beforeColon = String(part[part.startIndex..<colonIdx]).trim()
            let tokens = beforeColon.split(separator: " ")
            if tokens.count == 2 {
                let label = String(tokens[0])
                let paramName = String(tokens[1])
                return label == "_" ? paramName : "\(label): \(paramName)"
            } else {
                let name = String(tokens[0])
                return "\(name): \(name)"
            }
        }.joined(separator: ", ")
    }
}

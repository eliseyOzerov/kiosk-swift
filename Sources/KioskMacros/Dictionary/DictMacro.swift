import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

public struct DictMacro: MemberMacro, ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let properties = dictProperties(of: declaration)
    guard !properties.isEmpty else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: DictMacroDiagnostic(
            "@Dict requires at least one stored let or var property.",
            id: "no-stored-properties"
          )
        )
      )
      return []
    }

    let assignments = properties.map(\.assignment).joined(separator: "\n        ")
    let initializers = properties.map(\.initializer).joined(separator: "\n        ")
    let access = accessModifier(of: declaration)
    let accessPrefix = access.isEmpty ? "" : "\(access) "

    return [
      """
      \(raw: accessPrefix)init(fromDict dictionary: [String: Any]) {
          \(raw: initializers)
      }
      """,
      """
      \(raw: accessPrefix)func toDict() -> [String: Any] {
          var dictionary: [String: Any] = [:]
          \(raw: assignments)
          return dictionary
      }
      """
    ]
  }

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard !dictProperties(of: declaration).isEmpty else {
      return []
    }

    let ext: DeclSyntax = "extension \(type.trimmed): Dictable {}"
    return [ext.cast(ExtensionDeclSyntax.self)]
  }
}

private struct DictMacroDiagnostic: DiagnosticMessage {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity

  init(_ message: String, id: String, severity: DiagnosticSeverity = .error) {
    self.message = message
    self.diagnosticID = MessageID(domain: "KioskMacros", id: id)
    self.severity = severity
  }
}

private struct DictProperty {
  let name: String
  let type: String
  let decodedType: String
  let decodedCollection: DictCollection?
  let isOptional: Bool
  let isConstant: Bool
  let hasDefaultValue: Bool
  let key: String?
  let expands: Bool
  let isNative: Bool
  let usesValue: Bool
  let availability: String?

  private var keyExpression: String {
    if let key {
      return "\(key) as String"
    }

    return "\"\(name)\""
  }

  var assignment: String {
    let assignment: String
    if expands {
      if isOptional {
        assignment = "if let \(name) { dictionary.merge(\(name).toDict()) { _, new in new } }"
      } else {
        assignment = "dictionary.merge(\(name).toDict()) { _, new in new }"
      }
    } else {
      if isOptional {
        assignment = "if let \(name) { dictionary[\(keyExpression)] = \(encodedValueExpression) }"
      } else {
        assignment = "dictionary[\(keyExpression)] = \(encodedValueExpression)"
      }
    }

    guard let availability else { return assignment }
    return """
      if #available(\(availability)) {
          \(assignment)
      }
      """
  }

  var initializer: String {
    let initializer: String
    if isConstant && hasDefaultValue {
      initializer = ""
    } else if expands {
      initializer = "self.\(name) = \(decodedType)(fromDict: dictionary)"
    } else if isConstant && isOptional {
      initializer = "self.\(name) = \(decodeExpression)"
    } else if isOptional {
      initializer = "if let \(name): \(decodedType) = \(decodeExpression) { self.\(name) = \(name) }"
    } else if hasDefaultValue {
      initializer = "if let \(name): \(type) = \(decodeExpression) { self.\(name) = \(name) }"
    } else {
      initializer = """
        guard let \(name): \(type) = \(decodeExpression) else {
            fatalError("Missing dictionary value for \(name).")
        }
        self.\(name) = \(name)
        """
    }

    guard let availability else { return initializer }
    return """
      if #available(\(availability)) {
          \(initializer)
      }
      """
  }

  private var encodedValueExpression: String {
    if isNative {
      return name
    }

    if usesValue {
      return "DictValue.encodeValue(\(name))"
    }

    return "DictValue.encode(\(name))"
  }

  private var decodeExpression: String {
    if isNative {
      return "dictionary[\(keyExpression)] as? \(decodedType)"
    }

    if usesValue {
      return "DictValue.decodeValue(dictionary[\(keyExpression)])"
    }

    return switch decodedCollection {
    case .array(let elementType):
      "DictValue.decodeArray(dictionary[\(keyExpression)]) as [\(elementType)]?"
    case .dictionary(let valueType):
      "DictValue.decodeDictionary(dictionary[\(keyExpression)]) as [String: \(valueType)]?"
    case nil:
      "DictValue.decode(dictionary[\(keyExpression)])"
    }
  }
}

private enum DictCollection {
  case array(elementType: String)
  case dictionary(valueType: String)
}

private func dictProperties(of declaration: some DeclGroupSyntax) -> [DictProperty] {
  declaration.memberBlock.members.compactMap { member -> DictProperty? in
    guard let variable = member.decl.as(VariableDeclSyntax.self),
      ["let", "var"].contains(variable.bindingSpecifier.text),
      !variable.modifiers.contains(where: { $0.name.text == "static" }),
      variable.attribute(named: "Ignore") == nil,
      let binding = variable.bindings.first,
      let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
      let type = binding.typeAnnotation?.type
    else {
      return nil
    }

    let key = variable.attribute(named: "Key")?.argumentExpression(at: 0)
    let expands = variable.attribute(named: "Expand") != nil
    let isNative = variable.attribute(named: "Native") != nil
    let usesValue = variable.attribute(named: "UseValue") != nil
    let isOptional = type.is(OptionalTypeSyntax.self)
      || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
    let isConstant = variable.bindingSpecifier.text == "let"

    return DictProperty(
      name: pattern.identifier.text,
      type: type.trimmedDescription,
      decodedType: type.decodedTypeDescription,
      decodedCollection: type.decodedCollection,
      isOptional: isOptional,
      isConstant: isConstant,
      hasDefaultValue: binding.initializer != nil,
      key: key,
      expands: expands,
      isNative: isNative,
      usesValue: usesValue,
      availability: variable.availabilityCondition
    )
  }
}

extension TypeSyntax {
  fileprivate var decodedTypeDescription: String {
    if let type = self.as(OptionalTypeSyntax.self) {
      return type.wrappedType.trimmedDescription
    }

    if let type = self.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
      return type.wrappedType.trimmedDescription
    }

    return trimmedDescription
  }

  fileprivate var decodedCollection: DictCollection? {
    let type = unwrapped
    if let type = type.as(ArrayTypeSyntax.self) {
      return .array(elementType: type.element.trimmedDescription)
    }

    if let type = type.as(DictionaryTypeSyntax.self),
      type.key.trimmedDescription == "String"
    {
      return .dictionary(valueType: type.value.trimmedDescription)
    }

    return nil
  }

  private var unwrapped: TypeSyntax {
    if let type = self.as(OptionalTypeSyntax.self) {
      return type.wrappedType
    }

    if let type = self.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
      return type.wrappedType
    }

    return self
  }
}

extension AttributeSyntax {
  fileprivate func argumentExpression(at index: Int) -> String? {
    guard case .argumentList(let arguments) = arguments,
      arguments.indices.contains(arguments.index(arguments.startIndex, offsetBy: index))
    else {
      return nil
    }

    let argumentIndex = arguments.index(arguments.startIndex, offsetBy: index)
    return arguments[argumentIndex].expression.trimmedDescription
  }
}

extension VariableDeclSyntax {
  fileprivate var availabilityCondition: String? {
    guard let attribute = attribute(named: "available") else { return nil }
    let description = attribute.trimmedDescription
    guard let start = description.firstIndex(of: "("),
      let end = description.lastIndex(of: ")"),
      start < end
    else {
      return nil
    }

    return String(description[description.index(after: start)..<end])
  }
}

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

struct SerializableModel {
  private let properties: [SerializableProperty]
  private let declaresInitializer: Bool

  init?(_ declaration: some DeclGroupSyntax, context: some MacroExpansionContext) {
    let properties = declaration.memberBlock.members.flatMap { member -> [SerializableProperty] in
      guard let variable = member.decl.as(VariableDeclSyntax.self),
        !variable.modifiers.contains(where: { $0.name.text == "static" }),
        variable.bindings.count == 1,
        let binding = variable.bindings.first,
        binding.accessorBlock == nil,
        let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
        let type = binding.typeAnnotation?.type.trimmedDescription
      else {
        return []
      }

      let formatAttribute = variable.attribute(named: "Format")
      let defaultAttribute = variable.attribute(named: "Default")
      let serializableType = SerializableType(type)

      if let formatAttribute {
        Self.validate(format: formatAttribute, for: serializableType, in: context)
      }
      if let defaultAttribute {
        Self.validate(default: defaultAttribute, for: serializableType, in: context)
      }

      return [
        SerializableProperty(
          name: pattern.identifier.text,
          type: type,
          fieldName: variable.attribute(named: "Field").flatMap(
            AttributeArgument.firstStringLiteral),
          format: formatAttribute.flatMap(AttributeArgument.firstArgument),
          defaultValue: defaultAttribute.flatMap(AttributeArgument.firstArgument)
        )
      ]
    }

    self.properties = properties
    declaresInitializer = declaration.memberBlock.members.contains { member in
      member.decl.is(InitializerDeclSyntax.self)
    }
  }

  private static func validate(
    format attribute: AttributeSyntax,
    for type: SerializableType,
    in context: some MacroExpansionContext
  ) {
    guard let format = AttributeArgument.firstArgument(in: attribute) else {
      return
    }

    guard type.supports(format: format) else {
      context.diagnose(
        Diagnostic(
          node: Syntax(attribute),
          message: ApiUtilsMacroDiagnostic(
            "@Format(\(format)) is not supported for \(type.displayName).",
            id: "invalid-format"
          )
        )
      )
      return
    }
  }

  private static func validate(
    default attribute: AttributeSyntax,
    for type: SerializableType,
    in context: some MacroExpansionContext
  ) {
    guard let defaultValue = AttributeArgument.firstArgument(in: attribute) else {
      return
    }

    guard type.supports(defaultValue: defaultValue) else {
      context.diagnose(
        Diagnostic(
          node: Syntax(attribute),
          message: ApiUtilsMacroDiagnostic(
            "@Default(\(defaultValue)) is not compatible with \(type.displayName).",
            id: "invalid-default"
          )
        )
      )
      return
    }
  }

  func generatedMembers() -> [DeclSyntax] {
    guard !properties.isEmpty else {
      return []
    }

    var members: [DeclSyntax] = []
    if !declaresInitializer {
      members.append(memberwiseInitializer())
    }
    members.append(decoderInitializer())
    members.append(encoderFunction())
    return members
  }

  private func memberwiseInitializer() -> DeclSyntax {
    let parameters =
      properties
      .map { "\($0.name): \($0.type)" }
      .joined(separator: ", ")
    let assignments =
      properties
      .map { "    self.\($0.name) = \($0.name)" }
      .joined(separator: "\n")

    return """
      init(\(raw: parameters)) {
      \(raw: assignments)
      }
      """
  }

  private func decoderInitializer() -> DeclSyntax {
    let assignments = properties.map { "    \($0.decodeStatement)" }.joined(separator: "\n")

    return """
      init(from decoder: Decoder) throws {
          let serialization = SerializationContext(decoder: decoder)
          let container = try decoder.container(keyedBy: SerializationKey.self)
      \(raw: assignments)
      }
      """
  }

  private func encoderFunction() -> DeclSyntax {
    let statements = properties.map { "    \($0.encodeStatement)" }.joined(separator: "\n")

    return """
      func encode(to encoder: Encoder) throws {
          let serialization = SerializationContext(encoder: encoder)
          var container = encoder.container(keyedBy: SerializationKey.self)
      \(raw: statements)
      }
      """
  }
}

private struct SerializableType {
  let raw: String
  let name: String
  let isOptional: Bool

  var displayName: String {
    isOptional ? "\(name)?" : name
  }

  init(_ raw: String) {
    self.raw = raw

    if raw.hasSuffix("?") {
      isOptional = true
      name = Self.normalized(String(raw.dropLast()))
      return
    }

    if raw.hasPrefix("Optional<"), raw.hasSuffix(">") {
      isOptional = true
      name = Self.normalized(String(raw.dropFirst("Optional<".count).dropLast()))
      return
    }

    isOptional = false
    name = Self.normalized(raw)
  }

  func supports(format: String) -> Bool {
    switch normalizedFormat(format) {
    case ".json":
      return true
    case ".iso8601", ".secondsSince1970", ".millisecondsSince1970", ".custom":
      return name == "Date"
    case ".string":
      return ["String", "Date", "Bool", "URL", "UUID", "Decimal"].contains(name)
    default:
      return false
    }
  }

  func supports(defaultValue: String) -> Bool {
    let value = defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)

    if isOptional && value == "nil" {
      return true
    }

    switch name {
    case "String":
      return value.isStringLiteral
    case "Bool":
      return value == "true" || value == "false"
    case "Int":
      return value.isIntegerLiteral
    case "Double":
      return value.isNumericLiteral
    case "Date":
      return value.hasPrefix("Date(") || value == "Date()"
    case "URL":
      return value.hasPrefix("URL(")
    case "UUID":
      return value.hasPrefix("UUID(")
    case "Decimal":
      return value.hasPrefix("Decimal(") || value.isNumericLiteral
    default:
      return true
    }
  }

  private func normalizedFormat(_ format: String) -> String {
    let value = format.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix(".custom") {
      return ".custom"
    }

    return value
  }

  private static func normalized(_ type: String) -> String {
    let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.split(separator: ".").last.map(String.init) ?? trimmed
  }
}

extension String {
  fileprivate var isStringLiteral: Bool {
    hasPrefix("\"") && hasSuffix("\"")
  }

  fileprivate var isIntegerLiteral: Bool {
    let value = trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = value.drop(while: { $0 == "-" || $0 == "+" })
    return !digits.isEmpty && digits.allSatisfy(\.isNumber)
  }

  fileprivate var isNumericLiteral: Bool {
    Double(self) != nil
  }
}

private struct SerializableProperty {
  let name: String
  let type: String
  let fieldName: String?
  let format: String?
  let defaultValue: String?

  var decodeStatement: String {
    let formatArgument = format.map { ", format: \($0)" } ?? ""
    let fieldArgument = fieldName.map { ", renamed: \"\($0)\"" } ?? ""

    if let defaultValue {
      return
        "\(name) = try serialization.decode(\(decodedType).self, from: container, forField: \"\(name)\"\(fieldArgument)\(formatArgument), default: \(defaultValue))"
    }

    if isOptional {
      return
        "\(name) = try serialization.decodeIfPresent(\(decodedType).self, from: container, forField: \"\(name)\"\(fieldArgument)\(formatArgument))"
    }

    return
      "\(name) = try serialization.decode(\(decodedType).self, from: container, forField: \"\(name)\"\(fieldArgument)\(formatArgument))"
  }

  var encodeStatement: String {
    let formatArgument = format.map { ", format: \($0)" } ?? ""
    let fieldArgument = fieldName.map { ", renamed: \"\($0)\"" } ?? ""

    if isOptional {
      return
        "try serialization.encodeIfPresent(\(name), to: &container, forField: \"\(name)\"\(fieldArgument)\(formatArgument))"
    }

    return
      "try serialization.encode(\(name), to: &container, forField: \"\(name)\"\(fieldArgument)\(formatArgument))"
  }

  private var isOptional: Bool {
    type.hasSuffix("?") || (type.hasPrefix("Optional<") && type.hasSuffix(">"))
  }

  private var decodedType: String {
    if type.hasSuffix("?") {
      return String(type.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if type.hasPrefix("Optional<"), type.hasSuffix(">") {
      return String(type.dropFirst("Optional<".count).dropLast())
    }

    return type
  }
}

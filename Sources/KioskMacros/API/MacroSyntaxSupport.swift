import Foundation
import SwiftDiagnostics
import SwiftSyntax

struct ApiUtilsMacroDiagnostic: DiagnosticMessage {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity

  init(_ message: String, id: String, severity: DiagnosticSeverity = .error) {
    self.message = message
    self.diagnosticID = MessageID(domain: "ApiUtilsMacros", id: id)
    self.severity = severity
  }
}

enum AttributeArgument {
  static func firstStringLiteral(in attribute: AttributeSyntax) -> String? {
    firstStringLiteral(in: attribute.description)
  }

  static func firstArgument(in attribute: AttributeSyntax) -> String? {
    guard let open = attribute.description.firstIndex(of: "("),
      let close = attribute.description.lastIndex(of: ")"),
      open < close
    else {
      return nil
    }

    let body = attribute.description[attribute.description.index(after: open)..<close]
    guard let first = body.split(separator: ",", maxSplits: 1).first else {
      return nil
    }

    return first.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func secondArgument(in attribute: AttributeSyntax) -> String? {
    guard let open = attribute.description.firstIndex(of: "("),
      let close = attribute.description.lastIndex(of: ")"),
      open < close
    else {
      return nil
    }

    let body = attribute.description[attribute.description.index(after: open)..<close]
    let arguments = body.split(separator: ",", maxSplits: 2)
    guard arguments.count >= 2 else {
      return nil
    }

    return arguments[1].trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func thirdArgument(in attribute: AttributeSyntax) -> String? {
    guard let open = attribute.description.firstIndex(of: "("),
      let close = attribute.description.lastIndex(of: ")"),
      open < close
    else {
      return nil
    }

    let body = attribute.description[attribute.description.index(after: open)..<close]
    let arguments = body.split(separator: ",", maxSplits: 2)
    guard arguments.count == 3 else {
      return nil
    }

    return arguments[2].trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func stringLiteral(_ text: String) -> String? {
    firstStringLiteral(in: text)
  }

  private static func firstStringLiteral(in text: String) -> String? {
    guard let start = text.firstIndex(of: "\"") else {
      return nil
    }

    let remainder = text[text.index(after: start)...]
    guard let end = remainder.firstIndex(of: "\"") else {
      return nil
    }

    return String(remainder[..<end])
  }
}

/// Parsed `"label", Type.self` attribute payload shared by API route and endpoint macros.
struct LabeledTypeAttribute {
  let sourceLabel: String
  let label: String
  let type: String

  init?(_ attribute: AttributeSyntax) {
    guard let firstArgument = AttributeArgument.firstArgument(in: attribute),
      let label = AttributeArgument.stringLiteral(firstArgument),
      let secondArgument = AttributeArgument.secondArgument(in: attribute)
    else {
      return nil
    }

    self.sourceLabel = label
    self.label = label.camelCasedIdentifier
    self.type = secondArgument.replacingOccurrences(of: ".self", with: "")
  }
}

/// Parsed HTTP header attribute payload for endpoint header macros.
struct HeaderAttribute {
  let sourceLabel: String
  let label: String
  let keyExpression: String
  let type: String
  let defaultValue: String?

  init?(_ attribute: AttributeSyntax) {
    guard let firstArgument = AttributeArgument.firstArgument(in: attribute) else {
      return nil
    }

    let secondArgument = AttributeArgument.secondArgument(in: attribute)
    let second = secondArgument?.trimmingCharacters(in: .whitespacesAndNewlines)
    let explicitType = second?.hasSuffix(".self") == true
    let defaultArgument = second?.hasPrefix("default:") == true || second?.hasPrefix("defaultValue:") == true
    let hasStaticValue = second != nil && !explicitType && !defaultArgument

    if let literal = AttributeArgument.stringLiteral(firstArgument) {
      guard explicitType, let secondArgument else {
        return nil
      }

      sourceLabel = literal
      label = literal.camelCasedIdentifier
      type = secondArgument.replacingOccurrences(of: ".self", with: "")
      keyExpression = "HttpHeaderKey<\(type)>.custom(\"\(literal)\", as: \(type).self)"
      defaultValue = AttributeArgument.thirdArgument(in: attribute)?.macroDefaultValue
    } else {
      guard let headerType = Self.type(for: firstArgument) else {
        return nil
      }

      guard !hasStaticValue else {
        return nil
      }

      sourceLabel = firstArgument
      label = firstArgument.headerMemberName?.camelCasedIdentifier ?? firstArgument.camelCasedIdentifier
      type = explicitType
        ? secondArgument!.replacingOccurrences(of: ".self", with: "")
        : headerType
      keyExpression = Self.keyExpression(for: firstArgument, type: type)
      defaultValue = defaultArgument ? secondArgument?.macroDefaultValue : nil
    }
  }

  static func type(for expression: String) -> String? {
    switch expression.headerMemberName {
    case "accept", "contentType":
      return "HTTPContentType"
    case "contentLength":
      return "Int"
    case .some:
      return "String"
    case .none:
      return nil
    }
  }

  static func keyExpression(for expression: String, type: String) -> String {
    guard let member = expression.headerMemberName,
      expression.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("."),
      member.isSimpleSwiftIdentifier
    else {
      return expression
    }

    return "HttpHeaderKey<\(type)>.\(member)"
  }
}

/// Parsed static HTTP header attribute payload for path context macros.
struct StaticHeaderAttribute {
  let header: String

  static func all(in declaration: some DeclGroupSyntax) -> [StaticHeaderAttribute] {
    declaration.attributes.compactMap { element in
      guard let attribute = element.as(AttributeSyntax.self),
        attribute.attributeName.trimmedDescription == "Header"
      else {
        return nil
      }

      return StaticHeaderAttribute(attribute)
    }
  }

  init?(_ attribute: AttributeSyntax) {
    guard let firstArgument = AttributeArgument.firstArgument(in: attribute),
      let secondArgument = AttributeArgument.secondArgument(in: attribute),
      !secondArgument.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(".self"),
      !secondArgument.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("default:"),
      !secondArgument.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("defaultValue:")
    else {
      return nil
    }

    if let literal = AttributeArgument.stringLiteral(firstArgument) {
      header = "AnyHttpHeader(name: \"\(literal)\", value: String(describing: \(secondArgument)))"
    } else {
      let keyExpression = HeaderAttribute.keyExpression(
        for: firstArgument,
        type: HeaderAttribute.type(for: firstArgument) ?? "String"
      )
      header = "HttpHeader(\(keyExpression), \(secondArgument)).erased"
    }
  }
}

/// Parsed HTTP status attribute payload for endpoint result contract macros.
struct StatusAttribute {
  let statusExpression: String
  let caseName: String

  init?(_ attribute: AttributeSyntax) {
    guard let firstArgument = AttributeArgument.firstArgument(in: attribute) else {
      return nil
    }

    statusExpression = firstArgument
    caseName = firstArgument.statusCaseName
  }

  var hasNoBody: Bool {
    switch caseName {
    case "noContent", "resetContent", "status204", "status205":
      return true
    default:
      return false
    }
  }
}

/// Parsed single-value request content attribute payload for endpoint macros.
struct ContentAttribute {
  let type: String

  init?(_ attribute: AttributeSyntax) {
    guard let firstArgument = AttributeArgument.firstArgument(in: attribute),
      AttributeArgument.secondArgument(in: attribute) == nil,
      firstArgument.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(".self")
    else {
      return nil
    }

    type = firstArgument.replacingOccurrences(of: ".self", with: "")
  }
}

/// Parsed accepted response content type attribute payload.
struct AcceptAttribute {
  let contentType: String

  init?(_ attribute: AttributeSyntax) {
    guard let firstArgument = AttributeArgument.firstArgument(in: attribute) else {
      return nil
    }

    contentType = firstArgument
  }
}

/// Parsed request wrapper key attribute payload for endpoint and path macros.
struct WrapperAttribute {
  let key: String

  init?(_ attribute: AttributeSyntax) {
    guard let firstArgument = AttributeArgument.firstArgument(in: attribute) else {
      return nil
    }

    key = firstArgument
  }
}

struct RouteAttribute {
  let path: String?

  init(_ attribute: AttributeSyntax) {
    let arguments = attribute.description
    path = Self.unlabeledStringLiteral(in: arguments)
  }

  private static func unlabeledStringLiteral(in text: String) -> String? {
    guard let open = text.firstIndex(of: "("),
      let close = text.lastIndex(of: ")"),
      open < close
    else {
      return nil
    }

    let body = text[text.index(after: open)..<close]
    guard let first = body.split(separator: ",", maxSplits: 1).first else {
      return nil
    }

    let argument = first.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !argument.contains(":") else {
      return nil
    }

    return firstStringLiteral(in: argument)
  }

  private static func firstStringLiteral(in text: String) -> String? {
    guard let start = text.firstIndex(of: "\"") else {
      return nil
    }

    let remainder = text[text.index(after: start)...]
    guard let end = remainder.firstIndex(of: "\"") else {
      return nil
    }

    return String(remainder[..<end])
  }
}

extension DeclGroupSyntax {
  var genericParameterNames: [String] {
    if let declaration = self.as(StructDeclSyntax.self) {
      return declaration.genericParameterClause?.parameters.map(\.name.text) ?? []
    }

    if let declaration = self.as(ClassDeclSyntax.self) {
      return declaration.genericParameterClause?.parameters.map(\.name.text) ?? []
    }

    if let declaration = self.as(ActorDeclSyntax.self) {
      return declaration.genericParameterClause?.parameters.map(\.name.text) ?? []
    }

    return []
  }

  func attribute(named name: String) -> AttributeSyntax? {
    attributes.lazy.compactMap { element in
      element.as(AttributeSyntax.self)
    }
    .first { attribute in
      attribute.attributeName.trimmedDescription == name
    }
  }
}

extension AttributeSyntax {
  var hasArguments: Bool {
    description.contains("(")
  }
}

extension VariableDeclSyntax {
  func attribute(named name: String) -> AttributeSyntax? {
    attributes.lazy.compactMap { element in
      element.as(AttributeSyntax.self)
    }
    .first { attribute in
      attribute.attributeName.trimmedDescription == name
    }
  }
}

extension FunctionParameterSyntax {
  var localName: String {
    if let secondName, secondName.text != "_" {
      return secondName.text
    }

    return firstName.text
  }

  func attribute(named name: String) -> AttributeSyntax? {
    attributes.lazy.compactMap { element in
      element.as(AttributeSyntax.self)
    }
    .first { attribute in
      attribute.attributeName.trimmedDescription == name
    }
  }
}

extension String {
  var statusCaseName: String {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.allSatisfy(\.isNumber) {
      return "status\(trimmed)"
    }

    if trimmed.hasPrefix(".") {
      return String(trimmed.dropFirst()).camelCasedIdentifier
    }

    return trimmed.split(separator: ".").last.map { String($0).camelCasedIdentifier }
      ?? trimmed.camelCasedIdentifier
  }

  var headerMemberName: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix(".") {
      return String(trimmed.dropFirst())
    }

    return trimmed.split(separator: ".").last.map(String.init)
  }

  var macroDefaultValue: String {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("default:") {
      return String(trimmed.dropFirst("default:".count))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if trimmed.hasPrefix("defaultValue:") {
      return String(trimmed.dropFirst("defaultValue:".count))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return trimmed
  }

  var camelCasedIdentifier: String {
    let parts = split { character in
      !(character.isLetter || character.isNumber)
    }

    guard !parts.isEmpty else {
      return "_"
    }

    if parts.count == 1 {
      let candidate = String(parts[0]).lowercasedInitial
      return candidate.first?.isNumber == true ? "_\(candidate)" : candidate
    }

    let candidate = parts.enumerated()
      .map { index, part in
        let lowercased = String(part).lowercased()
        return index == 0 ? lowercased : lowercased.uppercasedInitial
      }
      .joined()

    return candidate.first?.isNumber == true ? "_\(candidate)" : candidate
  }

  var isSimpleSwiftIdentifier: Bool {
    guard let first else {
      return false
    }

    let allowedStart = first == "_" || first.isLetter
    guard allowedStart else {
      return false
    }

    return allSatisfy { character in
      character == "_" || character.isLetter || character.isNumber
    }
  }

  private var lowercasedInitial: String {
    guard let first else {
      return self
    }

    return first.lowercased() + String(dropFirst())
  }

  private var uppercasedInitial: String {
    guard let first else {
      return self
    }

    return first.uppercased() + String(dropFirst())
  }
}

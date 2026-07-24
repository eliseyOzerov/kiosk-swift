import SwiftSyntax
import SwiftSyntaxMacros

public struct ValuableMacro: MemberMacro, ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let enumDeclaration = declaration.as(EnumDeclSyntax.self) else {
      return []
    }

    let cases = valuableCases(of: enumDeclaration)
    guard !cases.isEmpty else { return [] }

    let valueType = node.explicitValueType
      ?? commonValueType(in: cases)
      ?? "Any"

    let valueCases = cases.map { enumCase in
      enumCase.valueSwitchCase
    }.joined(separator: "\n        ")

    let fromValueCases = cases.compactMap { enumCase in
      enumCase.fromValueCase(valueType: valueType)
    }.joined(separator: "\n        ")
    let access = accessModifier(of: declaration)
    let accessPrefix = access.isEmpty ? "" : "\(access) "

    let defaultCase = cases.count == enumDeclaration.caseCount
      ? ""
      : """

              default:
                  fatalError("Missing value mapping for \\(Self.self).")
      """

    return [
      """
      \(raw: accessPrefix)var value: \(raw: valueType) {
          switch self {
          \(raw: valueCases)
          \(raw: defaultCase)
          }
      }
      """,
      """
      \(raw: accessPrefix)static func fromValue(_ value: \(raw: valueType)) -> Self? {
          \(raw: fromValueCases)
          return nil
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
    let ext: DeclSyntax = "extension \(type.trimmed): Valuable {}"
    return [ext.cast(ExtensionDeclSyntax.self)]
  }
}

private enum ValuableCase {
  case fixed(FixedValueCase)
  case associated(AssociatedValueCase)

  var valueType: String? {
    switch self {
    case .fixed(let enumCase):
      enumCase.valueType
    case .associated(let enumCase):
      enumCase.type
    }
  }

  var valueSwitchCase: String {
    switch self {
    case .fixed(let enumCase):
      """
      case .\(enumCase.name):
          \(enumCase.value)
      """
    case .associated(let enumCase):
      """
      case .\(enumCase.patternExpression):
          value
      """
    }
  }

  func fromValueCase(valueType: String) -> String? {
    switch self {
    case .fixed(let enumCase):
      return """
      if DictValue.matches(value, \(enumCase.value)) {
          return .\(enumCase.name)
      }
      """
    case .associated(let enumCase):
      if valueType == enumCase.type {
        if let match = enumCase.match {
          return """
          let matchedValue = value
          do {
              let matches: (\(enumCase.type)) -> Bool = \(match)
              if matches(matchedValue) {
                  return .\(enumCase.callExpression(argument: "matchedValue"))
              }
          }
          """
        }

        return """
        return .\(enumCase.callExpression(argument: "value"))
        """
      }

      if let match = enumCase.match {
        return """
        if let matchedValue = value as? \(enumCase.type) {
            let matches: (\(enumCase.type)) -> Bool = \(match)
            if matches(matchedValue) {
                return .\(enumCase.callExpression(argument: "matchedValue"))
            }
        }
        """
      } else {
        return """
        if let matchedValue = value as? \(enumCase.type) {
            return .\(enumCase.callExpression(argument: "matchedValue"))
        }
        """
      }
    }
  }
}

private struct FixedValueCase {
  let name: String
  let value: String
  let valueType: String?
}

private struct AssociatedValueCase {
  let name: String
  let label: String?
  let type: String
  let match: String?

  var patternExpression: String {
    if let label {
      return "\(name)(\(label): let value)"
    }

    return "\(name)(let value)"
  }

  func callExpression(argument: String) -> String {
    if let label {
      return "\(name)(\(label): \(argument))"
    }

    return "\(name)(\(argument))"
  }
}

private func valuableCases(of declaration: EnumDeclSyntax) -> [ValuableCase] {
  declaration.memberBlock.members.flatMap { member -> [ValuableCase] in
    guard let enumCase = member.decl.as(EnumCaseDeclSyntax.self) else {
      return []
    }

    if let value = enumCase.attribute(named: "Value")?.argumentExpression(at: 0) {
      return enumCase.elements.compactMap { element -> ValuableCase? in
        guard element.parameterClause == nil else { return nil }
        return .fixed(FixedValueCase(
          name: element.name.text,
          value: value,
          valueType: enumCase.attribute(named: "Value")?.argument(at: 0)?.inferredValueType
        ))
      }
    }

    let match = enumCase.attribute(named: "MatchedValue")?.argumentExpression(at: 1)

    return enumCase.elements.compactMap { element -> ValuableCase? in
      guard let associatedValue = AssociatedValue(element: element, match: match) else {
        return nil
      }

      return .associated(AssociatedValueCase(
        name: element.name.text,
        label: associatedValue.label,
        type: associatedValue.type,
        match: associatedValue.match
      ))
    }
  }
}

private func commonValueType(in cases: [ValuableCase]) -> String? {
  let types = cases.compactMap(\.valueType)
  guard types.count == cases.count,
    let first = types.first,
    types.allSatisfy({ $0 == first })
  else {
    return nil
  }

  return first
}

private struct AssociatedValue {
  let label: String?
  let type: String
  let match: String?

  init?(element: EnumCaseElementSyntax, match: String?) {
    guard let parameterClause = element.parameterClause,
      parameterClause.parameters.count == 1,
      let parameter = parameterClause.parameters.first
    else {
      return nil
    }

    let label = parameter.firstName?.text
    self.label = label == "_" ? nil : label
    self.type = parameter.type.trimmedDescription
    self.match = match
  }
}

private extension EnumDeclSyntax {
  var caseCount: Int {
    memberBlock.members.reduce(into: 0) { result, member in
      guard let enumCase = member.decl.as(EnumCaseDeclSyntax.self) else { return }
      result += enumCase.elements.count
    }
  }
}

private extension EnumCaseDeclSyntax {
  func attribute(named name: String) -> AttributeSyntax? {
    attributes.compactMap { element -> AttributeSyntax? in
      guard case .attribute(let attribute) = element,
        attribute.attributeName.trimmedDescription == name
      else {
        return nil
      }

      return attribute
    }.first
  }
}

private extension AttributeSyntax {
  var explicitValueType: String? {
    argument(at: 0)?.explicitTypeExpression
  }

  func argument(at index: Int) -> ExprSyntax? {
    guard case .argumentList(let arguments) = arguments,
      arguments.indices.contains(arguments.index(arguments.startIndex, offsetBy: index))
    else {
      return nil
    }

    let argumentIndex = arguments.index(arguments.startIndex, offsetBy: index)
    return arguments[argumentIndex].expression
  }

  func argumentExpression(at index: Int) -> String? {
    argument(at: index)?.trimmedDescription
  }
}

private extension ExprSyntax {
  var explicitTypeExpression: String? {
    let expression = trimmedDescription
    guard expression.hasSuffix(".self") else {
      return nil
    }

    return String(expression.dropLast(".self".count))
  }

  var inferredValueType: String? {
    if self.is(BooleanLiteralExprSyntax.self) {
      return "Bool"
    }

    if self.is(StringLiteralExprSyntax.self) {
      return "String"
    }

    if self.is(IntegerLiteralExprSyntax.self) {
      return "Int"
    }

    if self.is(FloatLiteralExprSyntax.self) {
      return "Double"
    }

    if let expression = self.as(AsExprSyntax.self) {
      return expression.type.trimmedDescription
    }

    return explicitTypeExpression
  }
}

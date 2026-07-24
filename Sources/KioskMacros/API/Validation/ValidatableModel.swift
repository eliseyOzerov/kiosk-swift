import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

struct ValidatableModel {
  private let properties: [ValidatableProperty]

  init?(_ declaration: some DeclGroupSyntax, context: some MacroExpansionContext) {
    let properties = declaration.memberBlock.members.flatMap { member -> [ValidatableProperty] in
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

      let validationType = ValidationType(type)
      let property = ValidatableProperty(
        name: pattern.identifier.text,
        type: validationType,
        required: variable.attribute(named: "Required"),
        nonEmpty: variable.attribute(named: "NonEmpty"),
        range: variable.attribute(named: "Range").flatMap(ValidationArgument.init),
        pattern: variable.attribute(named: "Pattern").flatMap(ValidationArgument.init),
        past: variable.attribute(named: "Past"),
        future: variable.attribute(named: "Future"),
        custom: variable.attribute(named: "Validate").flatMap(ValidationArgument.init)
      )

      property.validate(in: context)

      return [property]
    }

    self.properties = properties
  }

  func generatedMembers() -> [DeclSyntax] {
    let statements =
      properties
      .flatMap(\.statements)
      .map { "    \($0)" }
      .joined(separator: "\n")

    return [
      """
      func validate() throws {
          let validation = ValidationContext()
      \(raw: statements)
      }
      """
    ]
  }
}

private struct ValidatableProperty {
  let name: String
  let type: ValidationType
  let required: AttributeSyntax?
  let nonEmpty: AttributeSyntax?
  let range: ValidationArgument?
  let pattern: ValidationArgument?
  let past: AttributeSyntax?
  let future: AttributeSyntax?
  let custom: ValidationArgument?

  var statements: [String] {
    var statements: [String] = []

    if required != nil {
      statements.append("try validation.required(\(name), field: \"\(name)\")")
    }
    if nonEmpty != nil {
      statements.append("try validation.nonEmpty(\(name), field: \"\(name)\")")
    }
    if let range {
      statements.append("try validation.range(\(name), \(range.expression), field: \"\(name)\")")
    }
    if let pattern {
      statements.append(
        "try validation.pattern(\(name), \(pattern.expression), field: \"\(name)\")")
    }
    if past != nil {
      statements.append("try validation.past(\(name), field: \"\(name)\")")
    }
    if future != nil {
      statements.append("try validation.future(\(name), field: \"\(name)\")")
    }
    if let custom {
      statements.append("try \(custom.expression)(\(name))")
    }

    return statements
  }

  func validate(in context: some MacroExpansionContext) {
    if let required, !type.isOptional {
      diagnose(
        "@Required is only supported for optional fields.", id: "invalid-required", node: required,
        in: context)
    }
    if let nonEmpty, !type.supportsNonEmpty {
      diagnose(
        "@NonEmpty is only supported for String and collection fields.", id: "invalid-nonempty",
        node: nonEmpty, in: context)
    }
    if let range, !type.supportsRange {
      diagnose(
        "@Range is only supported for number, String, Date, and collection fields.",
        id: "invalid-range", node: range.attribute, in: context)
    }
    if let pattern, !type.isString {
      diagnose(
        "@Pattern is only supported for String fields.", id: "invalid-pattern",
        node: pattern.attribute, in: context)
    }
    if let past, !type.isDate {
      diagnose(
        "@Past is only supported for Date fields.", id: "invalid-past", node: past, in: context)
    }
    if let future, !type.isDate {
      diagnose(
        "@Future is only supported for Date fields.", id: "invalid-future", node: future,
        in: context)
    }
  }

  private func diagnose(
    _ message: String,
    id: String,
    node: AttributeSyntax,
    in context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: Syntax(node),
        message: ApiUtilsMacroDiagnostic(message, id: id)
      )
    )
  }
}

private struct ValidationArgument {
  let attribute: AttributeSyntax
  let expression: String

  init?(_ attribute: AttributeSyntax) {
    guard let expression = AttributeArgument.firstArgument(in: attribute) else {
      return nil
    }

    self.attribute = attribute
    self.expression = expression
  }
}

private struct ValidationType {
  let raw: String
  let name: String
  let isOptional: Bool

  var isString: Bool {
    name == "String"
  }

  var isDate: Bool {
    name == "Date"
  }

  var supportsNonEmpty: Bool {
    isString || isCollection
  }

  var supportsRange: Bool {
    isNumber || isString || isDate || isCollection
  }

  private var isNumber: Bool {
    ["Int", "Double", "Float", "Decimal"].contains(name)
  }

  private var isCollection: Bool {
    raw.hasPrefix("[")
      || name.hasPrefix("Array<")
      || name.hasPrefix("Set<")
      || name.hasPrefix("Dictionary<")
  }

  init(_ raw: String) {
    self.raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    if self.raw.hasSuffix("?") {
      isOptional = true
      name = Self.normalized(String(self.raw.dropLast()))
      return
    }

    if self.raw.hasPrefix("Optional<"), self.raw.hasSuffix(">") {
      isOptional = true
      name = Self.normalized(String(self.raw.dropFirst("Optional<".count).dropLast()))
      return
    }

    isOptional = false
    name = Self.normalized(self.raw)
  }

  private static func normalized(_ type: String) -> String {
    let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("[") {
      return trimmed
    }

    return trimmed.split(separator: ".").last.map(String.init) ?? trimmed
  }
}

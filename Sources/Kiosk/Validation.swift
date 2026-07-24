import Foundation

/// Protocol for values that can validate themselves before use.
public protocol Validatable {
  func validate() throws
}

/// Named regular expression wrapper used by validation macros and helpers.
public struct ValidationPattern: ExpressibleByStringLiteral, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: String) {
    self.init(value)
  }
}

public extension ValidationPattern {
  static let email = ValidationPattern("^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$")
  static let url = ValidationPattern("^[a-z][a-z0-9+.-]*://[^\\s]+$")
  static let uuid = ValidationPattern(
    "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$")
  static let slug = ValidationPattern("^[a-z0-9]+(?:[-_][a-z0-9]+)*$")
}

/// Localized error describing a field validation failure.
public struct ValidationError: LocalizedError, Sendable {
  public let field: String
  public let rule: String

  public init(field: String, rule: String) {
    self.field = field
    self.rule = rule
  }

  public var errorDescription: String? {
    "\(field) failed \(rule) validation."
  }
}

/// Helper for validating request and serialized model fields.
public struct ValidationContext: Sendable {
  public init() {}

  public func required<Value>(_ value: Value?, field: String) throws {
    guard value != nil else {
      throw ValidationError(field: field, rule: "required")
    }
  }

  public func nonEmpty(_ value: String, field: String) throws {
    guard !value.isEmpty else {
      throw ValidationError(field: field, rule: "nonEmpty")
    }
  }

  public func nonEmpty(_ value: String?, field: String) throws {
    guard let value else { return }
    try nonEmpty(value, field: field)
  }

  public func nonEmpty<Value: Collection>(_ value: Value, field: String) throws {
    guard !value.isEmpty else {
      throw ValidationError(field: field, rule: "nonEmpty")
    }
  }

  public func nonEmpty<Value: Collection>(_ value: Value?, field: String) throws {
    guard let value else { return }
    try nonEmpty(value, field: field)
  }

  public func range<Value: Comparable>(_ value: Value, _ range: ClosedRange<Value>, field: String)
    throws
  {
    guard range.contains(value) else {
      throw ValidationError(field: field, rule: "range")
    }
  }

  public func range<Value: Comparable>(
    _ value: Value?,
    _ range: ClosedRange<Value>,
    field: String
  ) throws {
    guard let value else { return }
    try self.range(value, range, field: field)
  }

  public func range(_ value: String, _ range: ClosedRange<Int>, field: String) throws {
    guard range.contains(value.count) else {
      throw ValidationError(field: field, rule: "range")
    }
  }

  public func range(_ value: String?, _ range: ClosedRange<Int>, field: String) throws {
    guard let value else { return }
    try self.range(value, range, field: field)
  }

  public func range<Value: Collection>(_ value: Value, _ range: ClosedRange<Int>, field: String)
    throws
  {
    guard range.contains(value.count) else {
      throw ValidationError(field: field, rule: "range")
    }
  }

  public func range<Value: Collection>(
    _ value: Value?,
    _ range: ClosedRange<Int>,
    field: String
  ) throws {
    guard let value else { return }
    try self.range(value, range, field: field)
  }

  public func pattern(_ value: String, _ pattern: ValidationPattern, field: String) throws {
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    let expression = try NSRegularExpression(pattern: pattern.rawValue, options: [.caseInsensitive])
    guard expression.firstMatch(in: value, range: range) != nil else {
      throw ValidationError(field: field, rule: "pattern")
    }
  }

  public func pattern(_ value: String?, _ pattern: ValidationPattern, field: String) throws {
    guard let value else { return }
    try self.pattern(value, pattern, field: field)
  }

  public func past(_ value: Date, field: String, now: Date = Date()) throws {
    guard value < now else {
      throw ValidationError(field: field, rule: "past")
    }
  }

  public func past(_ value: Date?, field: String, now: Date = Date()) throws {
    guard let value else { return }
    try past(value, field: field, now: now)
  }

  public func future(_ value: Date, field: String, now: Date = Date()) throws {
    guard value > now else {
      throw ValidationError(field: field, rule: "future")
    }
  }

  public func future(_ value: Date?, field: String, now: Date = Date()) throws {
    guard let value else { return }
    try future(value, field: field, now: now)
  }
}

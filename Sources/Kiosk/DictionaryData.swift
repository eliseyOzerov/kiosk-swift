import Foundation

/// Protocol for values that can be encoded to and decoded from dictionaries by `@Dict`.
public protocol Dictable {
  init(fromDict dictionary: [String: Any])

  func toDict() -> [String: Any]
}

/// Protocol for types that expose a smaller persisted value for `@Valuable`.
public protocol Valuable {
  associatedtype ValuableValue = Any

  var value: ValuableValue { get }

  static func fromValue(_ value: ValuableValue) -> Self?
}

public extension Valuable {
  /// The wrapped value erased to `Any`.
  var anyValue: Any {
    value
  }

  /// Creates a value from an erased wrapped value when the type matches.
  static func fromAnyValue(_ value: Any) -> Self? {
    if ValuableValue.self == Any.self {
      return fromValue(value as! ValuableValue)
    }

    guard let value = value as? ValuableValue else {
      return nil
    }

    return fromValue(value)
  }
}

/// Helpers used by dictionary macros to encode, decode, and compare dynamic values.
public enum DictValue {
  public static func encode(_ value: Any) -> Any {
    if let value = value as? any Dictable {
      return value.toDict()
    }

    if let value = value as? [Any] {
      return value.map { encode($0) }
    }

    if let value = value as? [String: Any] {
      return value.mapValues { encode($0) }
    }

    return value
  }

  public static func encodeValue(_ value: Any) -> Any {
    if let value = value as? any Valuable {
      return value.anyValue
    }

    return value
  }

  public static func decode<Value>(_ value: Any?) -> Value? {
    guard let value else { return nil }

    if let value = value as? Value {
      return value
    }

    if let type = Value.self as? any Dictable.Type,
      let dictionary = value as? [String: Any]
    {
      return type.init(fromDict: dictionary) as? Value
    }

    return nil
  }

  public static func decodeValue<Value>(_ value: Any?) -> Value? {
    guard let value else { return nil }

    if let value = value as? Value {
      return value
    }

    if let type = Value.self as? any Valuable.Type {
      return type.fromAnyValue(value) as? Value
    }

    return nil
  }

  public static func decodeArray<Value>(_ value: Any?) -> [Value]? {
    if let value = value as? [Value] {
      return value
    }

    guard let value = value as? [Any] else {
      return nil
    }

    return value.reduce(into: [Value]()) { result, value in
      guard let value: Value = decode(value) else { return }
      result.append(value)
    }
  }

  public static func decodeDictionary<Value>(_ value: Any?) -> [String: Value]? {
    if let value = value as? [String: Value] {
      return value
    }

    guard let value = value as? [String: Any] else {
      return nil
    }

    return value.reduce(into: [String: Value]()) { result, entry in
      guard let value: Value = decode(entry.value) else { return }
      result[entry.key] = value
    }
  }

  public static func matches(_ lhs: Any, _ rhs: Any) -> Bool {
    guard let lhs = comparableValue(encodeValue(lhs)),
      let rhs = comparableValue(encodeValue(rhs))
    else {
      return false
    }

    return lhs == rhs
  }

  private static func comparableValue(_ value: Any) -> AnyHashable? {
    if let value = value as? NSString {
      return AnyHashable(value as String)
    }

    if let value = value as? NSNumber {
      return AnyHashable(value)
    }

    if let value = value as? String {
      return AnyHashable(value)
    }

    if let value = value as? any Hashable {
      return AnyHashable(value)
    }

    return nil
  }
}

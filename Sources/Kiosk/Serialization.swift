import Foundation

/// Marker protocol for models that use Kiosk serialization macros.
public protocol Serializable: Codable {}

/// Wire formats supported by `@Serializable` field conversion.
public enum SerializationFormat: Sendable {
  case json
  case iso8601
  case secondsSince1970
  case millisecondsSince1970
  case string
  case custom(String)
}

/// Runtime serialization configuration used by generated `@Serializable` code.
public struct SerializationSpec: Sendable {
  public var fields: SerializationFieldSpec
  public var formats: SerializationFormatSpec
  public var defaults: SerializationDefaultSpec

  public init(
    fields: SerializationFieldSpec = .init(),
    formats: SerializationFormatSpec = .init(),
    defaults: SerializationDefaultSpec = .init()
  ) {
    self.fields = fields
    self.formats = formats
    self.defaults = defaults
  }

  public static let `default` = SerializationSpec()
}

/// Field-name mapping configuration for serialized models.
public struct SerializationFieldSpec: Sendable {
  public var renaming: FieldRenamingStrategy

  public init(renaming: FieldRenamingStrategy = .identity) {
    self.renaming = renaming
  }

  public func key(for property: String, renamed explicitName: String? = nil) -> String {
    explicitName ?? renaming.rename(property)
  }
}

/// Strategy used to derive serialized field names from Swift property names.
public enum FieldRenamingStrategy: Sendable {
  case identity
  case snakeCase

  public func rename(_ field: String) -> String {
    switch self {
    case .identity:
      return field
    case .snakeCase:
      return field.convertedToSnakeCase()
    }
  }
}

/// Per-type format configuration for encoded values.
public struct SerializationFormatSpec: Sendable {
  public var date: SerializationFormat
  public var bool: SerializationFormat
  public var url: SerializationFormat
  public var uuid: SerializationFormat
  public var decimal: SerializationFormat

  public init(
    date: SerializationFormat = .iso8601,
    bool: SerializationFormat = .json,
    url: SerializationFormat = .string,
    uuid: SerializationFormat = .string,
    decimal: SerializationFormat = .json
  ) {
    self.date = date
    self.bool = bool
    self.url = url
    self.uuid = uuid
    self.decimal = decimal
  }

  public func format<Value>(for type: Value.Type) -> SerializationFormat? {
    if Value.self == Date.self {
      return date
    }
    if Value.self == Bool.self {
      return bool
    }
    if Value.self == URL.self {
      return url
    }
    if Value.self == UUID.self {
      return uuid
    }
    if Value.self == Decimal.self {
      return decimal
    }

    return nil
  }
}

/// Per-type fallback values used when serialized fields are missing or null.
public struct SerializationDefaultSpec: Sendable {
  public var string: String?
  public var bool: Bool?
  public var int: Int?
  public var double: Double?
  public var date: Date?
  public var url: URL?
  public var uuid: UUID?
  public var decimal: Decimal?

  public init(
    string: String? = nil,
    bool: Bool? = nil,
    int: Int? = nil,
    double: Double? = nil,
    date: Date? = nil,
    url: URL? = nil,
    uuid: UUID? = nil,
    decimal: Decimal? = nil
  ) {
    self.string = string
    self.bool = bool
    self.int = int
    self.double = double
    self.date = date
    self.url = url
    self.uuid = uuid
    self.decimal = decimal
  }

  public func value<Value>(for type: Value.Type) -> Value? {
    if Value.self == String.self {
      return string as? Value
    }
    if Value.self == Bool.self {
      return bool as? Value
    }
    if Value.self == Int.self {
      return int as? Value
    }
    if Value.self == Double.self {
      return double as? Value
    }
    if Value.self == Date.self {
      return date as? Value
    }
    if Value.self == URL.self {
      return url as? Value
    }
    if Value.self == UUID.self {
      return uuid as? Value
    }
    if Value.self == Decimal.self {
      return decimal as? Value
    }

    return nil
  }
}

/// Protocol for collection-like types that can provide serialization defaults.
public protocol SerializationDefaultValue {
  static var anySerializationDefaultValue: Any { get }
}

extension Array: SerializationDefaultValue {
  public static var anySerializationDefaultValue: Any {
    [] as [Element]
  }
}

/// Coding key type used by generated serialization implementations.
public struct SerializationKey: CodingKey, Hashable, Sendable {
  public let stringValue: String
  public let intValue: Int?

  public init(_ stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  public init?(stringValue: String) {
    self.init(stringValue)
  }

  public init?(intValue: Int) {
    self.stringValue = "\(intValue)"
    self.intValue = intValue
  }
}

/// Encoder and decoder context used by generated serialization implementations.
public struct SerializationContext: Sendable {
  public var spec: SerializationSpec

  public var dateFormat: SerializationFormat {
    get { spec.formats.date }
    set { spec.formats.date = newValue }
  }

  public var boolFormat: SerializationFormat {
    get { spec.formats.bool }
    set { spec.formats.bool = newValue }
  }

  public init(
    spec: SerializationSpec = .default
  ) {
    self.spec = spec
  }

  public init(
    dateFormat: SerializationFormat = .iso8601,
    boolFormat: SerializationFormat = .json
  ) {
    self.spec = SerializationSpec(
      formats: SerializationFormatSpec(
        date: dateFormat,
        bool: boolFormat
      )
    )
  }

  public static let `default` = SerializationContext()

  public init(decoder: Decoder) {
    self = decoder.userInfo[.serializationContext] as? SerializationContext ?? .default
  }

  public init(encoder: Encoder) {
    self = encoder.userInfo[.serializationContext] as? SerializationContext ?? .default
  }

  public func key(forField field: String, renamed explicitName: String? = nil) -> SerializationKey {
    SerializationKey(spec.fields.key(for: field, renamed: explicitName))
  }

  public func decode<Value: Decodable>(
    _ type: Value.Type,
    from container: KeyedDecodingContainer<SerializationKey>,
    forField field: String,
    renamed explicitName: String? = nil,
    format: SerializationFormat? = nil,
    default explicitDefault: Value? = nil
  ) throws -> Value {
    let key = key(forField: field, renamed: explicitName)
    if !container.contains(key) || containerValueIsNil(container, key: key) {
      if let explicitDefault {
        return explicitDefault
      }
      if let typeDefault: Value = spec.defaults.value(for: Value.self) {
        return typeDefault
      }
      if let defaultValue = (Value.self as? any SerializationDefaultValue.Type)?
        .anySerializationDefaultValue as? Value
      {
        return defaultValue
      }
    }

    return try decode(Value.self, from: container, forKey: key, format: format)
  }

  public func decodeIfPresent<Value: Decodable>(
    _ type: Value.Type,
    from container: KeyedDecodingContainer<SerializationKey>,
    forField field: String,
    renamed explicitName: String? = nil,
    format: SerializationFormat? = nil
  ) throws -> Value? {
    try decodeIfPresent(
      Value.self,
      from: container,
      forKey: key(forField: field, renamed: explicitName),
      format: format
    )
  }

  public func encode<Value: Encodable>(
    _ value: Value,
    to container: inout KeyedEncodingContainer<SerializationKey>,
    forField field: String,
    renamed explicitName: String? = nil,
    format: SerializationFormat? = nil
  ) throws {
    try encode(
      value,
      to: &container,
      forKey: key(forField: field, renamed: explicitName),
      format: format
    )
  }

  public func encodeIfPresent<Value: Encodable>(
    _ value: Value?,
    to container: inout KeyedEncodingContainer<SerializationKey>,
    forField field: String,
    renamed explicitName: String? = nil,
    format: SerializationFormat? = nil
  ) throws {
    try encodeIfPresent(
      value,
      to: &container,
      forKey: key(forField: field, renamed: explicitName),
      format: format
    )
  }

  public func decode<Value: Decodable, Key: CodingKey>(
    _ type: Value.Type,
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat? = nil
  ) throws -> Value {
    if !container.contains(key) || containerValueIsNil(container, key: key) {
      if let typeDefault: Value = spec.defaults.value(for: Value.self) {
        return typeDefault
      }
    }

    if Value.self == Date.self {
      return try decodeDate(from: container, forKey: key, format: format ?? spec.formats.date)
        as! Value
    }

    if Value.self == Bool.self {
      return try decodeBool(from: container, forKey: key, format: format ?? spec.formats.bool)
        as! Value
    }

    if Value.self == URL.self {
      return try decodeURL(from: container, forKey: key, format: format ?? spec.formats.url)
        as! Value
    }

    if Value.self == UUID.self {
      return try decodeUUID(from: container, forKey: key, format: format ?? spec.formats.uuid)
        as! Value
    }

    if Value.self == Decimal.self {
      return try decodeDecimal(from: container, forKey: key, format: format ?? spec.formats.decimal)
        as! Value
    }

    return try container.decode(Value.self, forKey: key)
  }

  public func decodeIfPresent<Value: Decodable, Key: CodingKey>(
    _ type: Value.Type,
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat? = nil
  ) throws -> Value? {
    if !container.contains(key) {
      return nil
    }

    if try container.decodeNil(forKey: key) {
      return nil
    }

    if Value.self == Date.self {
      return try decodeDate(from: container, forKey: key, format: format ?? spec.formats.date)
        as? Value
    }

    if Value.self == Bool.self {
      return try decodeBool(from: container, forKey: key, format: format ?? spec.formats.bool)
        as? Value
    }

    if Value.self == URL.self {
      return try decodeURL(from: container, forKey: key, format: format ?? spec.formats.url)
        as? Value
    }

    if Value.self == UUID.self {
      return try decodeUUID(from: container, forKey: key, format: format ?? spec.formats.uuid)
        as? Value
    }

    if Value.self == Decimal.self {
      return try decodeDecimal(from: container, forKey: key, format: format ?? spec.formats.decimal)
        as? Value
    }

    return try container.decodeIfPresent(Value.self, forKey: key)
  }

  public func encode<Value: Encodable, Key: CodingKey>(
    _ value: Value,
    to container: inout KeyedEncodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat? = nil
  ) throws {
    if let date = value as? Date {
      try encodeDate(date, to: &container, forKey: key, format: format ?? spec.formats.date)
      return
    }

    if let bool = value as? Bool {
      try encodeBool(bool, to: &container, forKey: key, format: format ?? spec.formats.bool)
      return
    }

    if let url = value as? URL {
      try encodeURL(url, to: &container, forKey: key, format: format ?? spec.formats.url)
      return
    }

    if let uuid = value as? UUID {
      try encodeUUID(uuid, to: &container, forKey: key, format: format ?? spec.formats.uuid)
      return
    }

    if let decimal = value as? Decimal {
      try encodeDecimal(
        decimal, to: &container, forKey: key, format: format ?? spec.formats.decimal)
      return
    }

    try container.encode(value, forKey: key)
  }

  public func encodeIfPresent<Value: Encodable, Key: CodingKey>(
    _ value: Value?,
    to container: inout KeyedEncodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat? = nil
  ) throws {
    guard let value else {
      return
    }

    try encode(value, to: &container, forKey: key, format: format)
  }

  private func decodeDate<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat
  ) throws -> Date {
    switch format {
    case .json:
      return try container.decode(Date.self, forKey: key)
    case .iso8601:
      let value = try container.decode(String.self, forKey: key)
      if let date = ISO8601DateFormatter().date(from: value) {
        return date
      }

      throw DecodingError.dataCorruptedError(
        forKey: key, in: container, debugDescription: "Expected ISO-8601 date string.")
    case .secondsSince1970:
      return try Date(timeIntervalSince1970: container.decode(Double.self, forKey: key))
    case .millisecondsSince1970:
      return try Date(timeIntervalSince1970: container.decode(Double.self, forKey: key) / 1_000)
    case .string:
      let value = try container.decode(String.self, forKey: key)
      if let date = ISO8601DateFormatter().date(from: value) {
        return date
      }

      throw DecodingError.dataCorruptedError(
        forKey: key, in: container, debugDescription: "Expected date string.")
    case .custom(let pattern):
      let value = try container.decode(String.self, forKey: key)
      let formatter = DateFormatter()
      formatter.dateFormat = pattern
      if let date = formatter.date(from: value) {
        return date
      }

      throw DecodingError.dataCorruptedError(
        forKey: key, in: container, debugDescription: "Expected date string matching \(pattern).")
    }
  }

  private func containerValueIsNil<Key: CodingKey>(
    _ container: KeyedDecodingContainer<Key>,
    key: Key
  ) -> Bool {
    (try? container.decodeNil(forKey: key)) ?? false
  }

  private func decodeBool<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat
  ) throws -> Bool {
    switch format {
    case .string:
      let value = try container.decode(String.self, forKey: key).lowercased()
      switch value {
      case "true", "1", "yes":
        return true
      case "false", "0", "no":
        return false
      default:
        throw DecodingError.dataCorruptedError(
          forKey: key, in: container, debugDescription: "Expected boolean string.")
      }
    default:
      return try container.decode(Bool.self, forKey: key)
    }
  }

  private func decodeURL<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat
  ) throws -> URL {
    switch format {
    case .string:
      let value = try container.decode(String.self, forKey: key)
      guard let url = URL(string: value) else {
        throw DecodingError.dataCorruptedError(
          forKey: key, in: container, debugDescription: "Expected URL string.")
      }

      return url
    default:
      return try container.decode(URL.self, forKey: key)
    }
  }

  private func decodeUUID<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat
  ) throws -> UUID {
    switch format {
    case .string:
      let value = try container.decode(String.self, forKey: key)
      guard let uuid = UUID(uuidString: value) else {
        throw DecodingError.dataCorruptedError(
          forKey: key, in: container, debugDescription: "Expected UUID string.")
      }

      return uuid
    default:
      return try container.decode(UUID.self, forKey: key)
    }
  }

  private func decodeDecimal<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat
  ) throws -> Decimal {
    switch format {
    case .string:
      let value = try container.decode(String.self, forKey: key)
      guard let decimal = Decimal(string: value) else {
        throw DecodingError.dataCorruptedError(
          forKey: key, in: container, debugDescription: "Expected decimal string.")
      }

      return decimal
    default:
      return try container.decode(Decimal.self, forKey: key)
    }
  }

  private func encodeDate<Key: CodingKey>(
    _ value: Date,
    to container: inout KeyedEncodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat
  ) throws {
    switch format {
    case .json:
      try container.encode(value, forKey: key)
    case .iso8601, .string:
      try container.encode(ISO8601DateFormatter().string(from: value), forKey: key)
    case .secondsSince1970:
      try container.encode(value.timeIntervalSince1970, forKey: key)
    case .millisecondsSince1970:
      try container.encode(value.timeIntervalSince1970 * 1_000, forKey: key)
    case .custom(let pattern):
      let formatter = DateFormatter()
      formatter.dateFormat = pattern
      try container.encode(formatter.string(from: value), forKey: key)
    }
  }

  private func encodeBool<Key: CodingKey>(
    _ value: Bool,
    to container: inout KeyedEncodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat
  ) throws {
    switch format {
    case .string:
      try container.encode(value ? "true" : "false", forKey: key)
    default:
      try container.encode(value, forKey: key)
    }
  }

  private func encodeURL<Key: CodingKey>(
    _ value: URL,
    to container: inout KeyedEncodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat
  ) throws {
    switch format {
    case .string:
      try container.encode(value.absoluteString, forKey: key)
    default:
      try container.encode(value, forKey: key)
    }
  }

  private func encodeUUID<Key: CodingKey>(
    _ value: UUID,
    to container: inout KeyedEncodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat
  ) throws {
    switch format {
    case .string:
      try container.encode(value.uuidString, forKey: key)
    default:
      try container.encode(value, forKey: key)
    }
  }

  private func encodeDecimal<Key: CodingKey>(
    _ value: Decimal,
    to container: inout KeyedEncodingContainer<Key>,
    forKey key: Key,
    format: SerializationFormat
  ) throws {
    switch format {
    case .string:
      try container.encode("\(value)", forKey: key)
    default:
      try container.encode(value, forKey: key)
    }
  }
}

extension CodingUserInfoKey {
  public static let serializationContext = CodingUserInfoKey(
    rawValue: "ApiUtils.SerializationContext")!
}

extension String {
  fileprivate func convertedToSnakeCase() -> String {
    unicodeScalars.reduce(into: "") { result, scalar in
      let character = Character(scalar)
      if CharacterSet.uppercaseLetters.contains(scalar) {
        if !result.isEmpty {
          result.append("_")
        }
        result.append(String(character).lowercased())
      } else {
        result.append(character)
      }
    }
  }
}

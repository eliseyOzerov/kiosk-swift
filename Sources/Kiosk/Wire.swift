import Foundation

/// Marker protocol for models that use Kiosk wire macros.
public protocol WireCodable: Codable {}

/// Document codec used by generated wire models.
public enum WireCodec: Sendable {
  case json
  case yaml
  case xml
}

/// Wire formats supported by `@Wire` value conversion.
public enum WireFormat: Sendable {
  case native
  case json
  case iso8601
  case secondsSince1970
  case millisecondsSince1970
  case string
  case base64
  case custom(String)
}

/// Runtime wire policy inherited through `HttpContext`.
public struct WireSpec: Sendable {
  public var codec: WireCodec
  public var fields: WireFieldSpec
  public var formats: WireValueFormats
  public var defaults: WireDefaults

  public init(
    codec: WireCodec = .json,
    fields: WireFieldSpec = .init(),
    formats: WireValueFormats = .jsonDefault,
    defaults: WireDefaults = .init()
  ) {
    self.codec = codec
    self.fields = fields
    self.formats = formats
    self.defaults = defaults
  }

  public static let `default` = WireSpec()

  public static func json(
    fields renaming: FieldRenamingStrategy = .identity,
    values formats: WireValueFormats = .jsonDefault,
    defaults: WireDefaults = .init()
  ) -> WireSpec {
    WireSpec(
      codec: .json,
      fields: WireFieldSpec(renaming: renaming),
      formats: formats,
      defaults: defaults
    )
  }

  public init(decoder: Decoder) {
    self = decoder.userInfo[.wireSpec] as? WireSpec ?? .default
  }

  public init(encoder: Encoder) {
    self = encoder.userInfo[.wireSpec] as? WireSpec ?? .default
  }

  public func codec(_ codec: WireCodec) -> WireSpec {
    var spec = self
    spec.codec = codec
    return spec
  }

  public func renaming(_ renaming: FieldRenamingStrategy) -> WireSpec {
    var spec = self
    spec.fields.renaming = renaming
    return spec
  }

  public func format<Value>(_ type: Value.Type, _ format: WireFormat) -> WireSpec {
    var spec = self
    spec.formats[type] = format
    return spec
  }

  public func `default`<Value>(_ type: Value.Type, _ value: Value) -> WireSpec {
    var spec = self
    spec.defaults[type] = value
    return spec
  }
}

/// Field-name mapping configuration for wire models.
public struct WireFieldSpec: Sendable {
  public var renaming: FieldRenamingStrategy

  public init(renaming: FieldRenamingStrategy = .identity) {
    self.renaming = renaming
  }

  public func key(for property: String, renamed explicitName: String? = nil) -> String {
    explicitName ?? renaming.rename(property)
  }
}

/// Strategy used to derive wire field names from Swift property names.
public enum FieldRenamingStrategy: Sendable {
  case identity
  case camelCase
  case pascalCase
  case snakeCase
  case screamingSnakeCase
  case kebabCase

  public func rename(_ field: String) -> String {
    switch self {
    case .identity:
      return field
    case .camelCase:
      return field.camelCased
    case .pascalCase:
      return field.camelCased.uppercasedInitial
    case .snakeCase:
      return field.convertedToSnakeCase()
    case .screamingSnakeCase:
      return field.convertedToSnakeCase().uppercased()
    case .kebabCase:
      return field.convertedToSnakeCase().replacingOccurrences(of: "_", with: "-")
    }
  }
}

/// Per-type value format registry.
public struct WireValueFormats: Sendable {
  private var formats: [ObjectIdentifier: WireFormat]

  public init() {
    formats = [:]
  }

  public init(_ formats: [ObjectIdentifier: WireFormat]) {
    self.formats = formats
  }

  public static var jsonDefault: WireValueFormats {
    WireValueFormats()
      .date(.iso8601)
      .bool(.json)
      .url(.string)
      .uuid(.string)
      .decimal(.json)
      .data(.base64)
  }

  public subscript<Value>(_ type: Value.Type) -> WireFormat? {
    get { formats[ObjectIdentifier(type)] }
    set { formats[ObjectIdentifier(type)] = newValue }
  }

  public func setting<Value>(_ type: Value.Type, _ format: WireFormat) -> WireValueFormats {
    var formats = self
    formats[type] = format
    return formats
  }

  public func date(_ format: WireFormat) -> WireValueFormats {
    setting(Date.self, format)
  }

  public func bool(_ format: WireFormat) -> WireValueFormats {
    setting(Bool.self, format)
  }

  public func url(_ format: WireFormat) -> WireValueFormats {
    setting(URL.self, format)
  }

  public func uuid(_ format: WireFormat) -> WireValueFormats {
    setting(UUID.self, format)
  }

  public func decimal(_ format: WireFormat) -> WireValueFormats {
    setting(Decimal.self, format)
  }

  public func data(_ format: WireFormat) -> WireValueFormats {
    setting(Data.self, format)
  }
}

/// Type-erased default value stored by `WireDefaults`.
public struct AnyWireDefault: @unchecked Sendable {
  public let value: Any

  public init(_ value: Any) {
    self.value = value
  }
}

/// Per-type fallback value registry used when wire fields are missing or null.
public struct WireDefaults: Sendable {
  private var values: [ObjectIdentifier: AnyWireDefault]

  public init() {
    values = [:]
  }

  public subscript<Value>(_ type: Value.Type) -> Value? {
    get { values[ObjectIdentifier(type)]?.value as? Value }
    set {
      if let newValue {
        values[ObjectIdentifier(type)] = AnyWireDefault(newValue)
      } else {
        values[ObjectIdentifier(type)] = nil
      }
    }
  }

  public func setting<Value>(_ type: Value.Type, _ value: Value) -> WireDefaults {
    var defaults = self
    defaults[type] = value
    return defaults
  }
}

/// Protocol for collection-like types that can provide wire defaults.
public protocol WireDefaultValue {
  static var anyWireDefaultValue: Any { get }
}

extension Array: WireDefaultValue {
  public static var anyWireDefaultValue: Any {
    [] as [Element]
  }
}

/// Coding key type used by generated wire implementations.
public struct WireKey: CodingKey, Hashable, Sendable {
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

extension WireSpec {
  public func key(forField field: String, renamed explicitName: String? = nil) -> WireKey {
    WireKey(fields.key(for: field, renamed: explicitName))
  }

  public func decode<Value: Decodable>(
    _ type: Value.Type,
    from container: KeyedDecodingContainer<WireKey>,
    forField field: String,
    renamed explicitName: String? = nil,
    format: WireFormat? = nil,
    default explicitDefault: Value? = nil
  ) throws -> Value {
    let key = key(forField: field, renamed: explicitName)
    if !container.contains(key) || containerValueIsNil(container, key: key) {
      if let explicitDefault {
        return explicitDefault
      }
      if let typeDefault: Value = defaults[Value.self] {
        return typeDefault
      }
      if let defaultValue = (Value.self as? any WireDefaultValue.Type)?
        .anyWireDefaultValue as? Value
      {
        return defaultValue
      }
    }

    return try decode(Value.self, from: container, forKey: key, format: format)
  }

  public func decodeIfPresent<Value: Decodable>(
    _ type: Value.Type,
    from container: KeyedDecodingContainer<WireKey>,
    forField field: String,
    renamed explicitName: String? = nil,
    format: WireFormat? = nil
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
    to container: inout KeyedEncodingContainer<WireKey>,
    forField field: String,
    renamed explicitName: String? = nil,
    format: WireFormat? = nil
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
    to container: inout KeyedEncodingContainer<WireKey>,
    forField field: String,
    renamed explicitName: String? = nil,
    format: WireFormat? = nil
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
    format: WireFormat? = nil
  ) throws -> Value {
    if !container.contains(key) || containerValueIsNil(container, key: key) {
      if let typeDefault: Value = defaults[Value.self] {
        return typeDefault
      }
    }

    if Value.self == Date.self {
      return try decodeDate(from: container, forKey: key, format: format ?? formats[Date.self] ?? .iso8601)
        as! Value
    }

    if Value.self == Bool.self {
      return try decodeBool(from: container, forKey: key, format: format ?? formats[Bool.self] ?? .json)
        as! Value
    }

    if Value.self == URL.self {
      return try decodeURL(from: container, forKey: key, format: format ?? formats[URL.self] ?? .string)
        as! Value
    }

    if Value.self == UUID.self {
      return try decodeUUID(from: container, forKey: key, format: format ?? formats[UUID.self] ?? .string)
        as! Value
    }

    if Value.self == Decimal.self {
      return try decodeDecimal(from: container, forKey: key, format: format ?? formats[Decimal.self] ?? .json)
        as! Value
    }

    if Value.self == Data.self {
      return try decodeData(from: container, forKey: key, format: format ?? formats[Data.self] ?? .base64)
        as! Value
    }

    return try container.decode(Value.self, forKey: key)
  }

  public func decodeIfPresent<Value: Decodable, Key: CodingKey>(
    _ type: Value.Type,
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key,
    format: WireFormat? = nil
  ) throws -> Value? {
    if !container.contains(key) {
      return nil
    }

    if try container.decodeNil(forKey: key) {
      return nil
    }

    if Value.self == Date.self {
      return try decodeDate(from: container, forKey: key, format: format ?? formats[Date.self] ?? .iso8601)
        as? Value
    }

    if Value.self == Bool.self {
      return try decodeBool(from: container, forKey: key, format: format ?? formats[Bool.self] ?? .json)
        as? Value
    }

    if Value.self == URL.self {
      return try decodeURL(from: container, forKey: key, format: format ?? formats[URL.self] ?? .string)
        as? Value
    }

    if Value.self == UUID.self {
      return try decodeUUID(from: container, forKey: key, format: format ?? formats[UUID.self] ?? .string)
        as? Value
    }

    if Value.self == Decimal.self {
      return try decodeDecimal(from: container, forKey: key, format: format ?? formats[Decimal.self] ?? .json)
        as? Value
    }

    if Value.self == Data.self {
      return try decodeData(from: container, forKey: key, format: format ?? formats[Data.self] ?? .base64)
        as? Value
    }

    return try container.decodeIfPresent(Value.self, forKey: key)
  }

  public func encode<Value: Encodable, Key: CodingKey>(
    _ value: Value,
    to container: inout KeyedEncodingContainer<Key>,
    forKey key: Key,
    format: WireFormat? = nil
  ) throws {
    if let date = value as? Date {
      try encodeDate(date, to: &container, forKey: key, format: format ?? formats[Date.self] ?? .iso8601)
      return
    }

    if let bool = value as? Bool {
      try encodeBool(bool, to: &container, forKey: key, format: format ?? formats[Bool.self] ?? .json)
      return
    }

    if let url = value as? URL {
      try encodeURL(url, to: &container, forKey: key, format: format ?? formats[URL.self] ?? .string)
      return
    }

    if let uuid = value as? UUID {
      try encodeUUID(uuid, to: &container, forKey: key, format: format ?? formats[UUID.self] ?? .string)
      return
    }

    if let decimal = value as? Decimal {
      try encodeDecimal(decimal, to: &container, forKey: key, format: format ?? formats[Decimal.self] ?? .json)
      return
    }

    if let data = value as? Data {
      try encodeData(data, to: &container, forKey: key, format: format ?? formats[Data.self] ?? .base64)
      return
    }

    try container.encode(value, forKey: key)
  }

  public func encodeIfPresent<Value: Encodable, Key: CodingKey>(
    _ value: Value?,
    to container: inout KeyedEncodingContainer<Key>,
    forKey key: Key,
    format: WireFormat? = nil
  ) throws {
    guard let value else {
      return
    }

    try encode(value, to: &container, forKey: key, format: format)
  }

  private func decodeDate<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key,
    format: WireFormat
  ) throws -> Date {
    switch format {
    case .native, .json:
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
    case .base64:
      throw DecodingError.dataCorruptedError(
        forKey: key, in: container, debugDescription: "Base64 is not supported for Date.")
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
    format: WireFormat
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
    format: WireFormat
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
    format: WireFormat
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
    format: WireFormat
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

  private func decodeData<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key,
    format: WireFormat
  ) throws -> Data {
    switch format {
    case .base64, .string:
      let value = try container.decode(String.self, forKey: key)
      guard let data = Data(base64Encoded: value) else {
        throw DecodingError.dataCorruptedError(
          forKey: key, in: container, debugDescription: "Expected base64 string.")
      }

      return data
    default:
      return try container.decode(Data.self, forKey: key)
    }
  }

  private func encodeDate<Key: CodingKey>(
    _ value: Date,
    to container: inout KeyedEncodingContainer<Key>,
    forKey key: Key,
    format: WireFormat
  ) throws {
    switch format {
    case .native, .json:
      try container.encode(value, forKey: key)
    case .iso8601, .string:
      try container.encode(ISO8601DateFormatter().string(from: value), forKey: key)
    case .secondsSince1970:
      try container.encode(value.timeIntervalSince1970, forKey: key)
    case .millisecondsSince1970:
      try container.encode(value.timeIntervalSince1970 * 1_000, forKey: key)
    case .base64:
      try container.encode(value, forKey: key)
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
    format: WireFormat
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
    format: WireFormat
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
    format: WireFormat
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
    format: WireFormat
  ) throws {
    switch format {
    case .string:
      try container.encode("\(value)", forKey: key)
    default:
      try container.encode(value, forKey: key)
    }
  }

  private func encodeData<Key: CodingKey>(
    _ value: Data,
    to container: inout KeyedEncodingContainer<Key>,
    forKey key: Key,
    format: WireFormat
  ) throws {
    switch format {
    case .base64, .string:
      try container.encode(value.base64EncodedString(), forKey: key)
    default:
      try container.encode(value, forKey: key)
    }
  }
}

extension CodingUserInfoKey {
  public static let wireSpec = CodingUserInfoKey(
    rawValue: "Kiosk.WireSpec")!
}

extension String {
  fileprivate var camelCased: String {
    let parts = split { character in
      !(character.isLetter || character.isNumber)
    }

    guard !parts.isEmpty else {
      return self
    }

    if parts.count == 1 {
      return lowercasedInitial
    }

    return parts.enumerated()
      .map { index, part in
        let lowercased = String(part).lowercased()
        return index == 0 ? lowercased : lowercased.uppercasedInitial
      }
      .joined()
  }

  fileprivate var lowercasedInitial: String {
    guard let first else {
      return self
    }

    return first.lowercased() + String(dropFirst())
  }

  fileprivate var uppercasedInitial: String {
    guard let first else {
      return self
    }

    return first.uppercased() + String(dropFirst())
  }

  fileprivate func convertedToSnakeCase() -> String {
    unicodeScalars.reduce(into: "") { result, scalar in
      let character = Character(scalar)
      if CharacterSet.uppercaseLetters.contains(scalar) {
        if !result.isEmpty {
          result.append("_")
        }
        result.append(String(character).lowercased())
      } else if character == "-" {
        result.append("_")
      } else {
        result.append(character)
      }
    }
  }
}

// MARK: - Routing macros

/// Generates path context storage and child path accessors for an API namespace.
@attached(member, names: arbitrary)
public macro Api(
  _ host: String? = nil,
  scheme: UrlScheme = .https,
  port: UrlPort? = nil,
  path: String? = nil
) = #externalMacro(module: "KioskMacros", type: "RouteMacro")

/// Generates path context storage and child path accessors for a URL namespace.
@attached(member, names: arbitrary)
public macro Path(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "RouteMacro")

/// Generates path context storage and child path accessors for a route namespace.
@available(*, deprecated, renamed: "Path")
@attached(member, names: arbitrary)
public macro Route(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "RouteMacro")

/// Marks a route or endpoint as having a dynamic path parameter.
@attached(member, names: arbitrary)
public macro Param(_ label: String, _ type: Any.Type) =
  #externalMacro(module: "KioskMacros", type: "ParamMacro")

/// Marks an endpoint as having a query parameter.
@attached(member, names: arbitrary)
public macro Query(_ label: String, _ type: Any.Type) =
  #externalMacro(module: "KioskMacros", type: "QueryMacro")

/// Marks a nested endpoint contract type or typealias as the query.
@attached(peer)
public macro Query() =
  #externalMacro(module: "KioskMacros", type: "QueryMacro")

/// Marks an endpoint as having a header parameter.
@attached(member, names: arbitrary)
public macro Header(
  _ name: HTTPHeaderFieldName,
  _ type: Any.Type,
  default defaultValue: Any? = nil
) =
  #externalMacro(module: "KioskMacros", type: "HeaderMacro")

/// Sets the request content type for an API path context or endpoint.
@attached(member, names: arbitrary)
public macro Content(_ contentType: HTTPContentType) =
  #externalMacro(module: "KioskMacros", type: "ContentMacro")

/// Sets the request content type and single-value content type for an endpoint.
@attached(member, names: arbitrary)
public macro Content(_ contentType: HTTPContentType, _ type: Any.Type) =
  #externalMacro(module: "KioskMacros", type: "ContentMacro")

/// Sets the accepted response content type for an API path context or endpoint.
@attached(member, names: arbitrary)
public macro Accept(_ contentType: HTTPContentType) =
  #externalMacro(module: "KioskMacros", type: "AcceptMacro")

/// Activates a registered request wrapper for an API path context or endpoint.
@attached(member, names: arbitrary)
public macro Wrap(_ key: WrapperKey) =
  #externalMacro(module: "KioskMacros", type: "WrapMacro")

/// Deactivates a request wrapper for an API path context or endpoint.
@attached(member, names: arbitrary)
public macro Unwrap(_ key: WrapperKey) =
  #externalMacro(module: "KioskMacros", type: "UnwrapMacro")

/// Marks an endpoint as having a structured request content field.
@attached(member, names: arbitrary)
public macro Field(_ label: String, _ type: Any.Type) =
  #externalMacro(module: "KioskMacros", type: "APIFieldMacro")

/// Marks an endpoint as having a multipart request content part.
@attached(member, names: arbitrary)
public macro Part(_ label: String, _ type: Any.Type) =
  #externalMacro(module: "KioskMacros", type: "PartMacro")

/// Marks a nested endpoint contract type as a response for an HTTP status code.
@attached(member, names: arbitrary)
@attached(extension, conformances: Serializable)
public macro Response(_ status: HTTPStatusCode) =
  #externalMacro(module: "KioskMacros", type: "ResponseMacro")

// MARK: - HTTP method macros

/// Generates a GET endpoint from an API endpoint struct.
@attached(member, names: arbitrary)
public macro Get(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "GetMacro")

/// Generates a POST endpoint from an API endpoint struct.
@attached(member, names: arbitrary)
public macro Post(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "PostMacro")

/// Generates a PUT endpoint from an API endpoint struct.
@attached(member, names: arbitrary)
public macro Put(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "PutMacro")

/// Generates a PATCH endpoint from an API endpoint struct.
@attached(member, names: arbitrary)
public macro Patch(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "PatchMacro")

/// Generates a DELETE endpoint from an API endpoint struct.
@attached(member, names: arbitrary)
public macro Delete(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "DeleteMacro")

// MARK: - Dictionary and value macros

/// Overrides the dictionary key emitted for a stored property.
@attached(peer)
public macro Key(_ name: Any) = #externalMacro(module: "KioskMacros", type: "KeyMacro")

/// Expands a nested dictionary value into the containing dictionary.
@attached(peer)
public macro Expand() = #externalMacro(module: "KioskMacros", type: "ExpandMacro")

/// Marks a property as natively encoded by the dictionary macro.
@attached(peer)
public macro Native() = #externalMacro(module: "KioskMacros", type: "NativeMacro")

/// Excludes a stored property from dictionary encoding and decoding.
@attached(peer)
public macro Ignore() = #externalMacro(module: "KioskMacros", type: "IgnoreMacro")

/// Uses a `Valuable` type's underlying value during dictionary encoding.
@attached(peer)
public macro UseValue() = #externalMacro(module: "KioskMacros", type: "UseValueMacro")

/// Generates dictionary encoding and decoding for a model.
@attached(member, names: named(init), named(toDict))
@attached(extension, conformances: Dictable)
public macro Dict() = #externalMacro(module: "KioskMacros", type: "DictMacro")

/// Generates `Valuable` conformance for enum-like value wrappers.
@attached(member, names: named(value), named(fromValue))
@attached(extension, conformances: Valuable)
public macro Valuable(_ valueType: Any.Type = Any.self) =
  #externalMacro(module: "KioskMacros", type: "ValuableMacro")

/// Assigns the encoded value for a `Valuable` case.
@attached(peer)
public macro Value(_ value: Any) = #externalMacro(module: "KioskMacros", type: "ValueMacro")

/// Assigns a matched encoded value for a `Valuable` case.
@attached(peer)
public macro MatchedValue<Value>(
  _ type: Value.Type,
  _ match: (Value) -> Bool
) = #externalMacro(module: "KioskMacros", type: "MatchedValueMacro")

// MARK: - Serialization macros

/// Generates Codable implementation using Kiosk serialization metadata.
@attached(member, names: arbitrary)
@attached(extension, conformances: Serializable)
public macro Serializable() = #externalMacro(module: "KioskMacros", type: "SerializableMacro")

/// Overrides a serialized field name.
@attached(peer)
public macro Field(_ name: String) = #externalMacro(module: "KioskMacros", type: "FieldMacro")

/// Overrides a serialized field format.
@attached(peer)
public macro Format(_ format: SerializationFormat) =
  #externalMacro(module: "KioskMacros", type: "FormatMacro")

/// Provides a serialized field default.
@attached(peer)
public macro Default(_ value: Any) =
  #externalMacro(module: "KioskMacros", type: "DefaultMacro")

// MARK: - Validation macros

/// Generates validation logic for a model.
@attached(member, names: arbitrary)
@attached(extension, conformances: Validatable)
public macro Validatable() = #externalMacro(module: "KioskMacros", type: "ValidatableMacro")

/// Requires an optional field to be non-nil.
@attached(peer)
public macro Required() = #externalMacro(module: "KioskMacros", type: "RequiredMacro")

/// Requires a string or collection field to be non-empty.
@attached(peer)
public macro NonEmpty() = #externalMacro(module: "KioskMacros", type: "NonEmptyMacro")

/// Requires a comparable, string, date, or collection field to be in range.
@attached(peer)
public macro Range(_ range: Any) = #externalMacro(module: "KioskMacros", type: "RangeMacro")

/// Requires a string field to match a validation pattern.
@attached(peer)
public macro Pattern(_ pattern: ValidationPattern) =
  #externalMacro(module: "KioskMacros", type: "PatternMacro")

/// Requires a date field to be in the past.
@attached(peer)
public macro Past() = #externalMacro(module: "KioskMacros", type: "PastMacro")

/// Requires a date field to be in the future.
@attached(peer)
public macro Future() = #externalMacro(module: "KioskMacros", type: "FutureMacro")

/// Applies a custom validator to a field.
@attached(peer)
public macro Validate(_ validator: Any) =
  #externalMacro(module: "KioskMacros", type: "ValidateMacro")

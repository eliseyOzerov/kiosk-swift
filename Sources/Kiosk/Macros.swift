// MARK: - Routing macros

/// Generates root API context storage.
@attached(member, names: arbitrary)
public macro Api(_ url: UrlBuilder = .init()) =
  #externalMacro(module: "KioskMacros", type: "RouteMacro")

/// Generates root API context storage.
@attached(member, names: arbitrary)
public macro Api(url: UrlBuilder) =
  #externalMacro(module: "KioskMacros", type: "RouteMacro")

/// Generates path context storage and a peer accessor when nested in a route namespace.
@attached(member, names: arbitrary)
@attached(peer, names: arbitrary)
public macro Path(_ path: String? = nil) =
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
public macro Header<Value: Sendable>(_ key: HttpHeaderKey<Value>) =
  #externalMacro(module: "KioskMacros", type: "HeaderMacro")

/// Marks an endpoint as having a header parameter.
@attached(member, names: arbitrary)
public macro Header<Value: Sendable>(
  _ key: HttpHeaderKey<Value>,
  _ type: Value.Type,
  default defaultValue: Value? = nil
) =
  #externalMacro(module: "KioskMacros", type: "HeaderMacro")

/// Marks an endpoint as having a custom header parameter.
@attached(member, names: arbitrary)
public macro Header(
  _ name: String,
  _ type: Any.Type,
  default defaultValue: Any? = nil
) =
  #externalMacro(module: "KioskMacros", type: "HeaderMacro")

/// Adds a default header to an API path context or endpoint.
@attached(member, names: arbitrary)
public macro Header<Value: Sendable>(_ key: HttpHeaderKey<Value>, _ value: Value) =
  #externalMacro(module: "KioskMacros", type: "HeaderMacro")

/// Adds a default custom header to an API path context or endpoint.
@attached(member, names: arbitrary)
public macro Header(_ name: String, _ value: String) =
  #externalMacro(module: "KioskMacros", type: "HeaderMacro")

/// Marks an endpoint as having a header parameter with a default value.
@attached(member, names: arbitrary)
public macro Header<Value: Sendable>(_ key: HttpHeaderKey<Value>, default defaultValue: Value) =
  #externalMacro(module: "KioskMacros", type: "HeaderMacro")

/// Marks an endpoint as having a single request content value.
@attached(member, names: arbitrary)
public macro Content(_ type: Any.Type) =
  #externalMacro(module: "KioskMacros", type: "ContentMacro")

/// Activates a registered request wrapper for an API path context or endpoint.
@attached(member, names: arbitrary)
public macro Wrap(_ key: WrapperKey) =
  #externalMacro(module: "KioskMacros", type: "WrapMacro")

/// Deactivates a request wrapper for an API path context or endpoint.
@attached(member, names: arbitrary)
public macro Unwrap(_ key: WrapperKey) =
  #externalMacro(module: "KioskMacros", type: "UnwrapMacro")

/// Marks a stored content property as a multipart part.
@attached(peer)
public macro Part(_ name: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "PartMacro")

/// Registers a scoped error body type for an HTTP status code.
@attached(member, names: arbitrary)
@attached(extension, conformances: WireCodable)
public macro Status(_ status: HTTPStatusCode) =
  #externalMacro(module: "KioskMacros", type: "StatusMacro")

// MARK: - HTTP method macros

/// Generates a GET endpoint from an API endpoint struct.
@attached(member, names: arbitrary)
@attached(peer, names: arbitrary)
public macro Get(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "GetMacro")

/// Generates a POST endpoint from an API endpoint struct.
@attached(member, names: arbitrary)
@attached(peer, names: arbitrary)
public macro Post(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "PostMacro")

/// Generates a PUT endpoint from an API endpoint struct.
@attached(member, names: arbitrary)
@attached(peer, names: arbitrary)
public macro Put(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "PutMacro")

/// Generates a PATCH endpoint from an API endpoint struct.
@attached(member, names: arbitrary)
@attached(peer, names: arbitrary)
public macro Patch(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "PatchMacro")

/// Generates a DELETE endpoint from an API endpoint struct.
@attached(member, names: arbitrary)
@attached(peer, names: arbitrary)
public macro Delete(_ path: String? = nil) =
  #externalMacro(module: "KioskMacros", type: "DeleteMacro")

// MARK: - Field metadata macros

/// Overrides the dictionary key emitted for a stored property.
@attached(peer)
public macro Key(_ name: Any) = #externalMacro(module: "KioskMacros", type: "KeyMacro")

// MARK: - Wire macros

/// Sets the inherited wire codec for an API path context or endpoint.
@attached(member, names: arbitrary)
public macro Codec(_ codec: WireCodec) =
  #externalMacro(module: "KioskMacros", type: "CodecMacro")

/// Sets the inherited wire field renaming strategy for an API path context or endpoint.
@attached(member, names: arbitrary)
public macro Rename(_ renaming: FieldRenamingStrategy) =
  #externalMacro(module: "KioskMacros", type: "RenameMacro")

/// Generates Codable implementation using Kiosk wire metadata.
@attached(member, names: arbitrary)
@attached(extension, conformances: WireCodable)
public macro Wire() = #externalMacro(module: "KioskMacros", type: "WireMacro")

/// Overrides a wire field name.
@attached(peer)
public macro Field(_ name: String) = #externalMacro(module: "KioskMacros", type: "FieldMacro")

/// Overrides a wire field format.
@attached(peer)
public macro Format(_ format: WireFormat) =
  #externalMacro(module: "KioskMacros", type: "FormatMacro")

/// Sets the inherited wire value format for a type.
@attached(member, names: arbitrary)
public macro Format<Value>(_ type: Value.Type, _ format: WireFormat) =
  #externalMacro(module: "KioskMacros", type: "FormatMacro")

/// Provides a wire field default.
@attached(peer)
public macro Default(_ value: Any) =
  #externalMacro(module: "KioskMacros", type: "DefaultMacro")

/// Sets the inherited wire default for a type.
@attached(member, names: arbitrary)
public macro Default<Value>(_ type: Value.Type, _ value: Value) =
  #externalMacro(module: "KioskMacros", type: "DefaultMacro")

import Foundation

// MARK: - Context base

/// Resolved HTTP context snapshot produced by folding a context node with its parents.
public struct ResolvedHttpContext: Sendable {
  public var session: URLSession
  public var url: UrlBuilder
  public var headers: HttpHeaderStorage
  public var contentType: HTTPContentType?
  public var accept: HTTPContentType?
  public var options: HttpOptions
  public var wire: WireSpec
  public var errors: HttpErrorDecoding
  public var wrappers: WrapperRegistry<any HttpWrapper>

  public init(
    session: URLSession = .shared,
    url: UrlBuilder = .init(),
    headers: HttpHeaderStorage = .init(),
    contentType: HTTPContentType? = nil,
    accept: HTTPContentType? = nil,
    options: HttpOptions = .init(),
    wire: WireSpec = .default,
    errors: HttpErrorDecoding = .init(),
    wrappers: WrapperRegistry<any HttpWrapper> = .init()
  ) {
    self.session = session
    self.url = url
    self.headers = headers
    self.contentType = contentType
    self.accept = accept
    self.options = options
    self.wire = wire
    self.errors = errors
    self.wrappers = wrappers
  }
}

/// Fluent HTTP client context node with inherited parent context.
public final class HttpContext: RequestContext, WrapperContext, @unchecked Sendable {
  /// Parent context inherited by this node.
  public let parent: HttpContext?

  private var sessionOverride: URLSession?
  private var schemeOverride: UrlScheme?
  private var hostOverride: String??
  private var portOverride: UrlPort??
  private var pathOverride: [UrlPathComponent]?
  private var queryOverride: [UrlQueryItem]?
  private var appendedPath: [UrlPathComponent]
  private var appendedQuery: [UrlQueryItem]
  private var localHeaders: HttpHeaderStorage
  private var replacesHeaders: Bool
  private var optionsOverride: HttpOptions?
  private var contentTypeOverride: HTTPContentType?
  private var acceptOverride: HTTPContentType?
  private var wireReplacement: WireSpec?
  private var localCodec: WireCodec?
  private var localRenaming: FieldRenamingStrategy?
  private var localFormats: WireValueFormats
  private var localDefaults: WireDefaults
  private var errorsReplacement: HttpErrorDecoding?
  private var localErrors: HttpErrorDecoding
  private var localWrappers: WrapperRegistry<any HttpWrapper>

  /// The base session.
  public var session: URLSession {
    get { fold().session }
    set { sessionOverride = newValue }
  }

  /// The folded URL builder.
  public var url: UrlBuilder {
    get { fold().url }
    set {
      schemeOverride = newValue.scheme
      hostOverride = .some(newValue.host)
      portOverride = .some(newValue.port)
      pathOverride = newValue.path
      queryOverride = newValue.query
      appendedPath = []
      appendedQuery = []
    }
  }

  /// The folded headers.
  public var headers: HttpHeaderStorage {
    get { fold().headers }
    set {
      localHeaders = newValue
      replacesHeaders = true
    }
  }

  /// Request content type inherited by generated API endpoints.
  public var contentType: HTTPContentType? {
    get { fold().contentType }
    set { contentTypeOverride = newValue }
  }

  /// Accepted response content type inherited by generated API endpoints.
  public var accept: HTTPContentType? {
    get { fold().accept }
    set { acceptOverride = newValue }
  }

  /// The options for the URL request.
  public var options: HttpOptions {
    get { fold().options }
    set { optionsOverride = newValue }
  }

  /// Wire settings for this context.
  public var wire: WireSpec {
    get { fold().wire }
    set { wireReplacement = newValue }
  }

  /// Error handling for this context.
  public var errors: HttpErrorDecoding {
    get { fold().errors }
    set { errorsReplacement = newValue }
  }

  /// Middleware for this context.
  public var wrappers: WrapperRegistry<any HttpWrapper> {
    get { fold().wrappers }
    set { localWrappers = newValue }
  }

  public init(
    parent: HttpContext? = nil,
    session: URLSession = .shared,
    url: UrlBuilder = .init(),
    headers: HttpHeaderStorage = .init(),
    contentType: HTTPContentType? = nil,
    accept: HTTPContentType? = nil,
    options: HttpOptions = .init(),
    wire: WireSpec = .default,
    errors: HttpErrorDecoding = .init(),
    wrappers: WrapperRegistry<any HttpWrapper> = .init()
  ) {
    self.parent = parent
    sessionOverride = parent == nil || session !== URLSession.shared ? session : nil
    schemeOverride = parent == nil ? url.scheme : nil
    hostOverride = parent == nil || url.host != nil ? .some(url.host) : nil
    portOverride = parent == nil || url.port != nil ? .some(url.port) : nil
    pathOverride = parent == nil || !url.path.isEmpty ? url.path : nil
    queryOverride = parent == nil || !url.query.isEmpty ? url.query : nil
    appendedPath = []
    appendedQuery = []
    localHeaders = headers
    replacesHeaders = parent == nil || !headers.isEmpty
    optionsOverride = parent == nil ? options : nil
    contentTypeOverride = contentType
    acceptOverride = accept
    wireReplacement = parent == nil ? wire : nil
    localCodec = nil
    localRenaming = nil
    localFormats = .init()
    localDefaults = .init()
    errorsReplacement = parent == nil ? errors : nil
    localErrors = .init()
    localWrappers = wrappers
  }

  public func child() -> HttpContext {
    HttpContext(parent: self)
  }

  public func fold() -> ResolvedHttpContext {
    var resolved = parent?.fold() ?? ResolvedHttpContext()

    if let sessionOverride {
      resolved.session = sessionOverride
    }

    if let schemeOverride {
      resolved.url.scheme = schemeOverride
    }
    if let hostOverride {
      resolved.url.host = hostOverride
    }
    if let portOverride {
      resolved.url.port = portOverride
    }
    if let pathOverride {
      resolved.url.path = pathOverride
    }
    for path in appendedPath {
      resolved.url = resolved.url.adding(path: path)
    }
    if let queryOverride {
      resolved.url.query = queryOverride
    }
    for query in appendedQuery {
      resolved.url = resolved.url.adding(query: query)
    }

    if replacesHeaders {
      resolved.headers = localHeaders
    } else {
      resolved.headers.set(localHeaders)
    }

    if let optionsOverride {
      resolved.options = optionsOverride
    }
    if let contentTypeOverride {
      resolved.contentType = contentTypeOverride
    }
    if let acceptOverride {
      resolved.accept = acceptOverride
    }

    if let wireReplacement {
      resolved.wire = wireReplacement
    }
    if let localCodec {
      resolved.wire.codec = localCodec
    }
    if let localRenaming {
      resolved.wire.fields.renaming = localRenaming
    }
    resolved.wire.formats = resolved.wire.formats.merging(localFormats)
    resolved.wire.defaults = resolved.wire.defaults.merging(localDefaults)

    if let errorsReplacement {
      resolved.errors = errorsReplacement
    }
    resolved.errors = resolved.errors.merging(localErrors)
    resolved.wrappers = resolved.wrappers.merging(localWrappers)

    return resolved
  }
}

extension HttpContext {
  public typealias Response<Body> = HttpResponse<Body>

  public enum Error: Swift.Error {
    case missingHost
    case invalidURL
    case invalidResponse(URLResponse)
    case unsuccessfulStatus(HTTPStatusCode, Data, HTTPURLResponse)
    case unexpectedStatus(HTTPStatusCode, Data)
    case unsupportedContentType(HTTPContentType)
  }
}

/// Error thrown for non-success HTTP responses with a registered `@Status` payload.
public struct HttpError<Payload: Decodable & Sendable>: Swift.Error {
  public let code: HTTPStatusCode
  public let message: String?
  public let payload: Payload

  public init(_ code: HTTPStatusCode, message: String? = nil, payload: Payload) {
    self.code = code
    self.message = message
    self.payload = payload
  }

  public init(code: HTTPStatusCode, message: String? = nil, payload: Payload) {
    self.code = code
    self.message = message
    self.payload = payload
  }

  public var status: HTTPStatusCode {
    code
  }
}

/// Empty payload used for status-only HTTP errors.
public struct EmptyHttpErrorPayload: Codable, Sendable, Equatable {
  public init() {}
}

extension HttpError where Payload == EmptyHttpErrorPayload {
  public init(_ code: HTTPStatusCode, message: String? = nil) {
    self.init(code, message: message, payload: EmptyHttpErrorPayload())
  }
}

extension HttpError: LocalizedError {
  public var errorDescription: String? {
    message ?? code.reasonPhrase
  }
}

extension HttpError: Equatable where Payload: Equatable {}

private struct HttpErrorMessage: Decodable {
  let message: String?
}

/// Sendable request value passed through HTTP wrappers and transport.
public struct HttpRequest: Sendable {
  public var method: HTTPMethod
  public var url: UrlBuilder
  public var headers: HttpHeaderStorage
  public var body: Data?
  public var options: HttpOptions

  public init(
    method: HTTPMethod,
    url: UrlBuilder,
    headers: HttpHeaderStorage = .init(),
    body: Data? = nil,
    options: HttpOptions = .init()
  ) {
    self.method = method
    self.url = url
    self.headers = headers
    self.body = body
    self.options = options
  }
}

/// HTTP response value containing body, status, headers, metadata, and final URL.
public struct HttpResponse<Body> {
  public var body: Body
  public var status: HTTPStatusCode
  public var headers: [AnyHttpHeader]
  public var mime: HTTPContentType?
  public var encoding: HTTPTextEncodingName?
  public var url: URL?

  public init(
    body: Body,
    status: HTTPStatusCode,
    headers: [AnyHttpHeader] = [],
    mime: HTTPContentType? = nil,
    encoding: HTTPTextEncodingName? = nil,
    url: URL? = nil
  ) {
    self.body = body
    self.status = status
    self.headers = headers
    self.mime = mime
    self.encoding = encoding
    self.url = url
  }
}

extension HttpResponse: Sendable where Body: Sendable {}

extension HttpResponse {
  public func header(_ name: String) -> String? {
    headers.last { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
  }

  public func headers(named name: String) -> [String] {
    headers.compactMap { $0.name.caseInsensitiveCompare(name) == .orderedSame ? $0.value : nil }
  }
}

/// Middleware protocol for wrapping HTTP request execution.
public protocol HttpWrapper: Sendable {
  var key: WrapperKey { get }

  func send(
    _ request: HttpRequest,
    next: @Sendable (HttpRequest) async throws -> HttpResponse<Data>
  ) async throws -> HttpResponse<Data>
}

extension HttpWrapper {
  public var key: WrapperKey {
    WrapperKey(String(reflecting: Self.self))
  }
}

/// Registry mapping status codes or classes to typed error decoders.
public struct HttpErrorDecoding: Sendable {
  private var statusDecoders: [HTTPStatusCode: HttpErrorDecoder]
  private var classDecoders: [HTTPStatusClass: HttpErrorDecoder]

  public init(
    statusDecoders: [HTTPStatusCode: HttpErrorDecoder] = [:],
    classDecoders: [HTTPStatusClass: HttpErrorDecoder] = [:]
  ) {
    self.statusDecoders = statusDecoders
    self.classDecoders = classDecoders
  }

  public func throwing<Payload: Decodable & Sendable>(
    _ payload: Payload.Type,
    for statusCode: HTTPStatusCode
  ) -> HttpErrorDecoding {
    var decoding = self
    decoding.statusDecoders[statusCode] = HttpErrorDecoder(Payload.self)
    return decoding
  }

  public func throwing<Payload: Decodable & Sendable>(
    _ payload: Payload.Type,
    for statusClass: HTTPStatusClass
  ) -> HttpErrorDecoding {
    var decoding = self
    decoding.classDecoders[statusClass] = HttpErrorDecoder(Payload.self)
    return decoding
  }

  func decode(
    statusCode: HTTPStatusCode,
    data: Data,
    response: HTTPURLResponse,
    wire: WireSpec
  ) throws -> (any Swift.Error)? {
    let decoder = statusDecoders[statusCode] ?? classDecoders[statusCode.statusClass]
    return try decoder?.decode(data, response, wire)
  }

  func merging(_ other: HttpErrorDecoding) -> HttpErrorDecoding {
    var decoding = self
    for (statusCode, decoder) in other.statusDecoders {
      decoding.statusDecoders[statusCode] = decoder
    }
    for (statusClass, decoder) in other.classDecoders {
      decoding.classDecoders[statusClass] = decoder
    }
    return decoding
  }
}

/// Type-erased decoder for converting HTTP error bodies into Swift errors.
public struct HttpErrorDecoder: Sendable {
  private let decodeError:
    @Sendable (Data, HTTPURLResponse, WireSpec) throws -> any Swift.Error

  public init<Payload: Decodable & Sendable>(_ payload: Payload.Type) {
    decodeError = { data, response, wire in
      let decoder = JSONDecoder()
      decoder.userInfo[.wireSpec] = wire
      let payload = try decoder.decode(Payload.self, from: data)
      let message = try? decoder.decode(HttpErrorMessage.self, from: data).message
      return HttpError(code: HTTPStatusCode(response.statusCode), message: message, payload: payload)
    }
  }

  public init(
    _ decodeError:
      @escaping @Sendable (Data, HTTPURLResponse, WireSpec) throws -> any Swift.Error
  ) {
    self.decodeError = decodeError
  }

  public func decode(
    _ data: Data,
    _ response: HTTPURLResponse,
    _ wire: WireSpec
  ) throws -> any Swift.Error {
    try decodeError(data, response, wire)
  }
}

/// URLRequest option overrides for HTTP requests.
public struct HttpOptions: Sendable {
  /// Overrides how this request interacts with URL caching.
  public var cachePolicy: URLRequest.CachePolicy?

  /// Overrides the idle timeout for this request.
  public var timeoutInterval: TimeInterval?

  /// Allows this request to use cellular interfaces.
  public var allowsCellularAccess: Bool?

  /// Allows this request to use expensive interfaces, such as cellular or personal hotspot.
  public var allowsExpensiveNetworkAccess: Bool?

  /// Allows this request to use constrained interfaces, such as Low Data Mode networks.
  public var allowsConstrainedNetworkAccess: Bool?

  /// Assumes this request's server supports HTTP/3, enabling QUIC racing without discovery.
  public var assumesHTTP3Capable: Bool?

  /// Creates request-specific overrides. Nil values inherit URLSession defaults.
  public init(
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil,
    allowsCellularAccess: Bool? = nil,
    allowsExpensiveNetworkAccess: Bool? = nil,
    allowsConstrainedNetworkAccess: Bool? = nil,
    assumesHTTP3Capable: Bool? = nil
  ) {
    self.cachePolicy = cachePolicy
    self.timeoutInterval = timeoutInterval
    self.allowsCellularAccess = allowsCellularAccess
    self.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
    self.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
    self.assumesHTTP3Capable = assumesHTTP3Capable
  }

  func merging(_ other: HttpOptions) -> HttpOptions {
    HttpOptions(
      cachePolicy: other.cachePolicy ?? cachePolicy,
      timeoutInterval: other.timeoutInterval ?? timeoutInterval,
      allowsCellularAccess: other.allowsCellularAccess ?? allowsCellularAccess,
      allowsExpensiveNetworkAccess: other.allowsExpensiveNetworkAccess ?? allowsExpensiveNetworkAccess,
      allowsConstrainedNetworkAccess: other.allowsConstrainedNetworkAccess ?? allowsConstrainedNetworkAccess,
      assumesHTTP3Capable: other.assumesHTTP3Capable ?? assumesHTTP3Capable
    )
  }
}

/// Encodes endpoint request content according to the active HTTP content type.
public enum HTTPContentEncoder {
  public static func encode<Content>(
    _ content: Content,
    as contentType: HTTPContentType,
    wire: WireSpec
  ) throws -> Data {
    if contentType.isJSON {
      return try encodeJSON(content, wire: wire)
    }

    if contentType.isForm {
      return encodeForm(content)
    }

    if contentType.isMultipart,
      let boundary = contentType.multipartBoundary
    {
      return try encodeMultipart(content, boundary: boundary)
    }

    if contentType.isBinary,
      let data = content as? Data
    {
      return data
    }

    if contentType.isText,
      let text = content as? String
    {
      return Data(text.utf8)
    }

    throw HttpContext.Error.unsupportedContentType(contentType)
  }

  private static func encodeJSON<Content>(
    _ content: Content,
    wire: WireSpec
  ) throws -> Data {
    guard let encodable = content as? any Encodable else {
      throw HttpContext.Error.unsupportedContentType(.json)
    }

    let encoder = JSONEncoder()
    encoder.userInfo[.wireSpec] = wire
    return try encoder.encode(AnyEncodable(encodable))
  }

  private static func encodeForm<Content>(_ content: Content) -> Data {
    let queryItems = UrlQueryEncoder.encode(content, keys: contentKeys(for: content))
    let form = queryItems.map { item in
      let name = encodeFormComponent(item.name)
      guard let value = item.value else {
        return name
      }

      return "\(name)=\(encodeFormComponent(value))"
    }
    .joined(separator: "&")
    return Data(form.utf8)
  }

  private static func encodeMultipart<Content>(
    _ content: Content,
    boundary: String
  ) throws -> Data {
    var data = Data()
    let keys = contentKeys(for: content)
    let children = Array(Mirror(reflecting: content).children)

    for child in children {
      guard let label = child.label,
        !label.hasPrefix("__")
      else {
        continue
      }

      let field = label.hasPrefix("_") ? String(label.dropFirst()) : label
      let name = keys[field] ?? field
      guard let value = unwrapOptional(child.value) else {
        continue
      }

      data.appendMultipartLine("--\(boundary)")
      data.appendMultipartLine("Content-Disposition: form-data; name=\"\(name)\"")

      if let part = value as? Data {
        data.appendMultipartLine("Content-Type: \(HTTPContentType.binary.rawValue)")
        data.appendMultipartLine("")
        data.append(part)
        data.appendMultipartLine("")
      } else if let text = UrlQueryEncoder.queryValue(value) {
        data.appendMultipartLine("")
        data.appendMultipartLine(text)
      } else {
        throw HttpContext.Error.unsupportedContentType(.multipart(boundary: boundary))
      }
    }

    data.appendMultipartLine("--\(boundary)--")
    return data
  }

  private static func contentKeys<Content>(for content: Content) -> [String: String] {
    guard let keyed = type(of: content) as? any HTTPContentKeyProviding.Type else {
      return [:]
    }

    return keyed.contentKeys
  }

  private static func unwrapOptional(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)
    guard mirror.displayStyle == .optional else {
      return value
    }

    return mirror.children.first?.value
  }

  private static func encodeFormComponent(_ value: String) -> String {
    value.utf8.map { byte -> String in
      switch byte {
      case 48...57, 65...90, 97...122, 45, 46, 95, 42:
        return String(UnicodeScalar(byte))
      case 32:
        return "+"
      default:
        return String(format: "%%%02X", byte)
      }
    }
    .joined()
  }
}

private struct AnyEncodable: Encodable {
  let value: any Encodable

  init(_ value: any Encodable) {
    self.value = value
  }

  func encode(to encoder: Encoder) throws {
    try value.encode(to: encoder)
  }
}

private extension Data {
  mutating func appendMultipartLine(_ string: String) {
    append(Data(string.utf8))
    append(Data("\r\n".utf8))
  }
}

// MARK: - Fluent builder

extension HttpContext {
  public func url(_ url: UrlBuilder) -> HttpContext {
    self.url = url
    return self
  }

  public func scheme(_ scheme: UrlScheme) -> HttpContext {
    schemeOverride = scheme
    return self
  }

  public func host(_ host: String?) -> HttpContext {
    hostOverride = .some(host)
    return self
  }

  public func port(_ port: UrlPort?) -> HttpContext {
    portOverride = .some(port)
    return self
  }

  public func path(_ path: [UrlPathComponent]) -> HttpContext {
    pathOverride = path
    appendedPath = []
    return self
  }

  public func query(_ query: [UrlQueryItem]) -> HttpContext {
    queryOverride = query
    appendedQuery = []
    return self
  }

  public func headers(_ headers: HttpHeaderStorage) -> HttpContext {
    localHeaders = headers
    replacesHeaders = true
    return self
  }

  public func headers(_ headers: [AnyHttpHeader]) -> HttpContext {
    self.headers(HttpHeaderStorage(headers))
  }

  public func options(_ options: HttpOptions) -> HttpContext {
    optionsOverride = options
    return self
  }

  public func adding(path component: UrlPathComponent) -> HttpContext {
    if pathOverride != nil {
      pathOverride?.append(component)
    } else {
      appendedPath.append(component)
    }
    return self
  }

  public func adding(query item: UrlQueryItem) -> HttpContext {
    if queryOverride != nil {
      queryOverride?.append(item)
    } else {
      appendedQuery.append(item)
    }
    return self
  }

  public func adding(query items: [UrlQueryItem]) -> HttpContext {
    for item in items {
      _ = adding(query: item)
    }
    return self
  }

  public func adding(header: AnyHttpHeader) -> HttpContext {
    localHeaders.set(header)
    return self
  }

  public func adding<Value: Sendable>(header: HttpHeader<Value>) -> HttpContext {
    adding(header: header.erased)
  }

  public func set(header: AnyHttpHeader) -> HttpContext {
    adding(header: header)
  }

  public func set<Value: Sendable>(header: HttpHeader<Value>) -> HttpContext {
    adding(header: header)
  }

  public func adding(headers: [AnyHttpHeader]) -> HttpContext {
    localHeaders.set(headers)
    return self
  }

  public func adding(headers: HttpHeaderStorage) -> HttpContext {
    localHeaders.set(headers)
    return self
  }

  public func session(_ session: URLSession) -> HttpContext {
    sessionOverride = session
    return self
  }

  public func wire(_ wire: WireSpec) -> HttpContext {
    wireReplacement = wire
    return self
  }

  public func codec(_ codec: WireCodec) -> HttpContext {
    if var wireReplacement {
      wireReplacement.codec = codec
      self.wireReplacement = wireReplacement
    } else {
      localCodec = codec
    }
    return self
  }

  public func rename(_ renaming: FieldRenamingStrategy) -> HttpContext {
    if var wireReplacement {
      wireReplacement.fields.renaming = renaming
      self.wireReplacement = wireReplacement
    } else {
      localRenaming = renaming
    }
    return self
  }

  public func format<Value>(_ type: Value.Type, _ format: WireFormat) -> HttpContext {
    if var wireReplacement {
      wireReplacement.formats[type] = format
      self.wireReplacement = wireReplacement
    } else {
      localFormats[type] = format
    }
    return self
  }

  public func wireDefault<Value>(_ type: Value.Type, _ value: Value) -> HttpContext {
    if var wireReplacement {
      wireReplacement.defaults.set(type, value)
      self.wireReplacement = wireReplacement
    } else {
      localDefaults.set(type, value)
    }
    return self
  }

  public func errors(_ errors: HttpErrorDecoding) -> HttpContext {
    errorsReplacement = errors
    return self
  }

  public func content(_ contentType: HTTPContentType) -> HttpContext {
    contentTypeOverride = contentType
    return self
  }

  public func accept(_ accept: HTTPContentType) -> HttpContext {
    acceptOverride = accept
    return self
  }

  public func throwing<Failure: Decodable & Sendable>(
    _ failure: Failure.Type,
    for statusCode: HTTPStatusCode
  ) -> HttpContext {
    localErrors = localErrors.throwing(Failure.self, for: statusCode)
    return self
  }

  public func throwing<Failure: Decodable & Sendable>(
    _ failure: Failure.Type,
    for statusClass: HTTPStatusClass
  ) -> HttpContext {
    localErrors = localErrors.throwing(Failure.self, for: statusClass)
    return self
  }

  public func register(_ key: WrapperKey, _ wrapper: any HttpWrapper) -> HttpContext {
    localWrappers[key] = wrapper
    return self
  }

  public func register(
    _ key: WrapperKey,
    factory: @escaping @Sendable () -> any HttpWrapper
  ) -> HttpContext {
    localWrappers.set(key, factory: factory)
    return self
  }

  public func wrap(
    _ key: WrapperKey,
    _ wrapper: (any HttpWrapper)? = nil,
    activate: Bool = true
  ) -> HttpContext {
    if let wrapper {
      localWrappers[key] = wrapper
    }
    if activate {
      localWrappers.activate(key)
    }
    return self
  }

  public func wrap(
    _ key: WrapperKey,
    activate: Bool = true,
    factory: @escaping @Sendable () -> any HttpWrapper
  ) -> HttpContext {
    localWrappers.set(key, factory: factory)
    if activate {
      localWrappers.activate(key)
    }
    return self
  }

  public func unwrap(_ key: WrapperKey) -> HttpContext {
    localWrappers.deactivate(key)
    return self
  }

  public func unwrapped() -> HttpContext {
    localWrappers.deactivateAll()
    return self
  }
}

// MARK: - HTTP Methods

extension HttpContext {
  public func get() async throws -> Response<Data> {
    try await data(for: .get)
  }

  public func get<ResponseBody: Decodable>(
    as responseBody: ResponseBody.Type = ResponseBody.self
  ) async throws -> Response<ResponseBody> {
    try await decode(ResponseBody.self, from: get())
  }

  public func head() async throws -> Response<Void> {
    let response = try await data(for: .head)
    return Response(
      body: (),
      status: response.status,
      headers: response.headers,
      mime: response.mime,
      encoding: response.encoding,
      url: response.url
    )
  }

  public func options() async throws -> Response<Data> {
    try await data(for: .options)
  }

  public func options<ResponseBody: Decodable>(
    as responseBody: ResponseBody.Type = ResponseBody.self
  ) async throws -> Response<ResponseBody> {
    try await decode(ResponseBody.self, from: options())
  }

  public func post() async throws -> Response<Data> {
    try await data(for: .post)
  }

  public func post<ResponseBody: Decodable>(
    as responseBody: ResponseBody.Type = ResponseBody.self
  ) async throws -> Response<ResponseBody> {
    try await decode(ResponseBody.self, from: post())
  }

  public func post<RequestBody: Encodable>(
    json requestBody: RequestBody
  ) async throws -> Response<Data> {
    try await data(for: .post, json: requestBody)
  }

  public func post<RequestBody: Encodable, ResponseBody: Decodable>(
    json requestBody: RequestBody,
    as responseBody: ResponseBody.Type = ResponseBody.self
  ) async throws -> Response<ResponseBody> {
    try await decode(ResponseBody.self, from: post(json: requestBody))
  }

  public func put() async throws -> Response<Data> {
    try await data(for: .put)
  }

  public func put<ResponseBody: Decodable>(
    as responseBody: ResponseBody.Type = ResponseBody.self
  ) async throws -> Response<ResponseBody> {
    try await decode(ResponseBody.self, from: put())
  }

  public func put<RequestBody: Encodable>(
    json requestBody: RequestBody
  ) async throws -> Response<Data> {
    try await data(for: .put, json: requestBody)
  }

  public func put<RequestBody: Encodable, ResponseBody: Decodable>(
    json requestBody: RequestBody,
    as responseBody: ResponseBody.Type = ResponseBody.self
  ) async throws -> Response<ResponseBody> {
    try await decode(ResponseBody.self, from: put(json: requestBody))
  }

  public func patch() async throws -> Response<Data> {
    try await data(for: .patch)
  }

  public func patch<ResponseBody: Decodable>(
    as responseBody: ResponseBody.Type = ResponseBody.self
  ) async throws -> Response<ResponseBody> {
    try await decode(ResponseBody.self, from: patch())
  }

  public func patch<RequestBody: Encodable>(
    json requestBody: RequestBody
  ) async throws -> Response<Data> {
    try await data(for: .patch, json: requestBody)
  }

  public func patch<RequestBody: Encodable, ResponseBody: Decodable>(
    json requestBody: RequestBody,
    as responseBody: ResponseBody.Type = ResponseBody.self
  ) async throws -> Response<ResponseBody> {
    try await decode(ResponseBody.self, from: patch(json: requestBody))
  }

  public func delete() async throws -> Response<Data> {
    try await data(for: .delete)
  }

  public func delete<ResponseBody: Decodable>(
    as responseBody: ResponseBody.Type = ResponseBody.self
  ) async throws -> Response<ResponseBody> {
    try await decode(ResponseBody.self, from: delete())
  }

  public func delete<RequestBody: Encodable>(
    json requestBody: RequestBody
  ) async throws -> Response<Data> {
    try await data(for: .delete, json: requestBody)
  }

  public func delete<RequestBody: Encodable, ResponseBody: Decodable>(
    json requestBody: RequestBody,
    as responseBody: ResponseBody.Type = ResponseBody.self
  ) async throws -> Response<ResponseBody> {
    try await decode(ResponseBody.self, from: delete(json: requestBody))
  }
}

// MARK: - Utils

extension HttpContext {
  public func response(for method: HTTPMethod) async throws -> Response<Data> {
    try await send(method: method, body: nil, validatesStatus: false)
  }

  public func response<RequestBody: Encodable>(
    for method: HTTPMethod,
    json requestBody: RequestBody
  ) async throws -> Response<Data> {
    let context = fold()
    let encoder = JSONEncoder()
    encoder.userInfo[.wireSpec] = context.wire
    let body = try encoder.encode(requestBody)
    return try await send(
      method: method,
      body: body,
      headers: [HttpHeader(.contentType, .json).erased],
      validatesStatus: false
    )
  }

  public func response<Content>(
    for method: HTTPMethod,
    content: Content
  ) async throws -> Response<Data> {
    let context = fold()
    let contentType = context.contentType
      ?? context.headers.get(.contentType).flatMap(HTTPContentType.init(validating:))
      ?? .json
    let body = try HTTPContentEncoder.encode(
      content,
      as: contentType,
      wire: context.wire
    )
    return try await send(
      method: method,
      body: body,
      headers: [HttpHeader(.contentType, contentType).erased],
      validatesStatus: false
    )
  }

  func makeURL() throws -> URL {
    try makeURL(from: fold().url)
  }

  func makeURL(from url: UrlBuilder) throws -> URL {
    do {
      return try url.build()
    } catch UrlBuilder.Error.missingHost {
      throw Error.missingHost
    } catch UrlBuilder.Error.invalidURL {
      throw Error.invalidURL
    }
  }

  public func data(for method: HTTPMethod) async throws -> Response<Data> {
    try await send(method: method, body: nil)
  }

  func data<RequestBody: Encodable>(
    for method: HTTPMethod,
    json requestBody: RequestBody
  ) async throws -> Response<Data> {
    let context = fold()
    let encoder = JSONEncoder()
    encoder.userInfo[.wireSpec] = context.wire
    let body = try encoder.encode(requestBody)
    return try await send(method: method, body: body, headers: [HttpHeader(.contentType, .json).erased])
  }

  public func data<Content>(
    for method: HTTPMethod,
    content: Content
  ) async throws -> Response<Data> {
    let context = fold()
    let contentType = context.contentType
      ?? context.headers.get(.contentType).flatMap(HTTPContentType.init(validating:))
      ?? .json
    let body = try HTTPContentEncoder.encode(
      content,
      as: contentType,
      wire: context.wire
    )
    return try await send(method: method, body: body, headers: [HttpHeader(.contentType, contentType).erased])
  }

  private var headerContentType: HTTPContentType? {
    headers.get(.contentType).flatMap(HTTPContentType.init(validating:))
  }

  func send(
    method: HTTPMethod,
    body: Data?,
    headers additionalHeaders: [AnyHttpHeader] = [],
    options overrideOptions: HttpOptions? = nil,
    validatesStatus: Bool = true
  ) async throws -> Response<Data> {
    let context = fold()
    let request = HttpRequest(
      method: method,
      url: context.url,
      headers: context.headers.merging(additionalHeaders),
      body: body,
      options: overrideOptions ?? context.options
    )

    let transport: @Sendable (HttpRequest) async throws -> Response<Data> = { request in
      try await self.perform(request, in: context, validatesStatus: validatesStatus)
    }

    let pipeline = activeWrappers(in: context).reversed().reduce(transport) { next, wrapper in
      { request in
        try await wrapper.send(request, next: next)
      }
    }

    return try await pipeline(request)
  }

  private func perform(
    _ request: HttpRequest,
    in context: ResolvedHttpContext,
    validatesStatus: Bool
  ) async throws -> Response<Data> {
    var urlRequest = URLRequest(url: try makeURL(from: request.url))
    urlRequest.httpMethod = request.method.rawValue
    urlRequest.httpBody = request.body
    urlRequest.setValue(
      (context.accept ?? .json).rawValue,
      forHTTPHeaderField: HttpHeaderKey<HTTPContentType>.accept.name)

    request.options.apply(to: &urlRequest)

    for header in request.headers {
      urlRequest.setValue(header.value, forHTTPHeaderField: header.name)
    }

    let (data, response) = try await context.session.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw Error.invalidResponse(response)
    }

    let status = HTTPStatusCode(httpResponse.statusCode)
    guard status.isSuccess || !validatesStatus else {
      if let error = try context.errors.decode(
        statusCode: status,
        data: data,
        response: httpResponse,
        wire: context.wire
      ) {
        throw error
      }

      throw Error.unsuccessfulStatus(status, data, httpResponse)
    }

    return Response(
      body: data,
      status: status,
      headers: httpResponse.httpHeaders,
      mime: httpResponse.mimeType.flatMap(HTTPContentType.init(validating:)),
      encoding: httpResponse.textEncodingName.flatMap(HTTPTextEncodingName.init(validating:)),
      url: httpResponse.url
    )
  }

  public func decode<ResponseBody: Decodable>(
    _ responseBody: ResponseBody.Type,
    from response: Response<Data>
  ) throws -> Response<ResponseBody> {
    let context = fold()
    let decoder = JSONDecoder()
    decoder.userInfo[.wireSpec] = context.wire
    return Response(
      body: try decoder.decode(ResponseBody.self, from: response.body),
      status: response.status,
      headers: response.headers,
      mime: response.mime,
      encoding: response.encoding,
      url: response.url
    )
  }

  public func validate(_ response: Response<Data>) throws {
    guard response.status.isSuccess == false else {
      return
    }

    let context = fold()
    let url = response.url ?? (try? makeURL(from: context.url)) ?? URL(string: "https://kiosk.local")!
    let headerFields = Dictionary(uniqueKeysWithValues: response.headers.map { ($0.name, $0.value) })
    let httpResponse = HTTPURLResponse(
      url: url,
      statusCode: response.status.rawValue,
      httpVersion: nil,
      headerFields: headerFields
    )!

    if let error = try context.errors.decode(
      statusCode: response.status,
      data: response.body,
      response: httpResponse,
      wire: context.wire
    ) {
      throw error
    }

    throw Error.unexpectedStatus(response.status, response.body)
  }
}

extension HttpContext {
  fileprivate func activeWrappers(in context: ResolvedHttpContext) -> [any HttpWrapper] {
    context.wrappers.activeKeys.compactMap { context.wrappers.resolve($0) }
  }
}

extension HttpOptions {
  fileprivate func apply(to request: inout URLRequest) {
    if let cachePolicy {
      request.cachePolicy = cachePolicy
    }
    if let timeoutInterval {
      request.timeoutInterval = timeoutInterval
    }
    if let allowsCellularAccess {
      request.allowsCellularAccess = allowsCellularAccess
    }
    if let allowsExpensiveNetworkAccess {
      request.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
    }
    if let allowsConstrainedNetworkAccess {
      request.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
    }
    if let assumesHTTP3Capable {
      request.assumesHTTP3Capable = assumesHTTP3Capable
    }
  }
}

extension HTTPURLResponse {
  fileprivate var httpHeaders: [AnyHttpHeader] {
    allHeaderFields.map { key, value in
      AnyHttpHeader(name: String(describing: key), value: String(describing: value))
    }
  }
}

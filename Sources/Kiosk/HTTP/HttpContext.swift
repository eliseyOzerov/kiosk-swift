import Foundation

// MARK: - Context base

/// Fluent HTTP client context with URL, headers, options, serialization, errors, and wrappers.
public struct HttpContext: RequestContext, WrapperContext, Sendable {
  /// The base session
  public var session: URLSession
  /// The url builder we're using under the hood
  public var url: UrlBuilder
  /// The currently active headers
  public var headers: [HttpHeader]
  /// Request content type inherited by generated API endpoints.
  public var contentType: HTTPContentType?
  /// Accepted response content type inherited by generated API endpoints.
  public var accept: HTTPContentType?
  /// The options for the URL request
  public var options: HttpOptions
  /// Serialization settings for this context
  public var serialization: SerializationContext
  /// Error handling for this context
  public var errors: HttpErrorDecoding
  /// Middleware for this context
  public var wrappers: WrapperRegistry<any HttpWrapper>

  public init(
    session: URLSession = .shared,
    url: UrlBuilder = .init(),
    headers: [HttpHeader] = [],
    contentType: HTTPContentType? = nil,
    accept: HTTPContentType? = nil,
    options: HttpOptions = .init(),
    serialization: SerializationContext = .default,
    errors: HttpErrorDecoding = .init(),
    wrappers: WrapperRegistry<any HttpWrapper> = .init()
  ) {
    self.session = session
    self.url = url
    self.headers = headers
    self.contentType = contentType
    self.accept = accept
    self.options = options
    self.serialization = serialization
    self.errors = errors
    self.wrappers = wrappers
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

/// Sendable request value passed through HTTP wrappers and transport.
public struct HttpRequest: Sendable {
  public var method: HTTPMethod
  public var url: UrlBuilder
  public var headers: [HttpHeader]
  public var body: Data?
  public var options: HttpOptions

  public init(
    method: HTTPMethod,
    url: UrlBuilder,
    headers: [HttpHeader] = [],
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
  public var headers: [HttpHeader]
  public var mime: HTTPContentType?
  public var encoding: HTTPTextEncodingName?
  public var url: URL?

  public init(
    body: Body,
    status: HTTPStatusCode,
    headers: [HttpHeader] = [],
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
  public func header(_ name: HTTPHeaderFieldName) -> String? {
    headers.last { $0.name == name }?.value
  }

  public func headers(named name: HTTPHeaderFieldName) -> [String] {
    headers.compactMap { $0.name == name ? $0.value : nil }
  }
}

/// Middleware protocol for wrapping HTTP request execution.
public protocol HttpWrapper: Sendable {
  func send(
    _ request: HttpRequest,
    next: @Sendable (HttpRequest) async throws -> HttpResponse<Data>
  ) async throws -> HttpResponse<Data>
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

  public func throwing<Failure: Decodable & Swift.Error>(
    _ failure: Failure.Type,
    for statusCode: HTTPStatusCode
  ) -> HttpErrorDecoding {
    var decoding = self
    decoding.statusDecoders[statusCode] = HttpErrorDecoder(Failure.self)
    return decoding
  }

  public func throwing<Failure: Decodable & Swift.Error>(
    _ failure: Failure.Type,
    for statusClass: HTTPStatusClass
  ) -> HttpErrorDecoding {
    var decoding = self
    decoding.classDecoders[statusClass] = HttpErrorDecoder(Failure.self)
    return decoding
  }

  func decode(
    statusCode: HTTPStatusCode,
    data: Data,
    response: HTTPURLResponse,
    serialization: SerializationContext
  ) throws -> (any Swift.Error)? {
    let decoder = statusDecoders[statusCode] ?? classDecoders[statusCode.statusClass]
    return try decoder?.decode(data, response, serialization)
  }
}

/// Type-erased decoder for converting HTTP error bodies into Swift errors.
public struct HttpErrorDecoder: Sendable {
  private let decodeError:
    @Sendable (Data, HTTPURLResponse, SerializationContext) throws -> any Swift.Error

  public init<Failure: Decodable & Swift.Error>(_ failure: Failure.Type) {
    decodeError = { data, _, serialization in
      let decoder = JSONDecoder()
      decoder.userInfo[.serializationContext] = serialization
      return try decoder.decode(Failure.self, from: data)
    }
  }

  public init(
    _ decodeError:
      @escaping @Sendable (Data, HTTPURLResponse, SerializationContext) throws -> any Swift.Error
  ) {
    self.decodeError = decodeError
  }

  public func decode(
    _ data: Data,
    _ response: HTTPURLResponse,
    _ serialization: SerializationContext
  ) throws -> any Swift.Error {
    try decodeError(data, response, serialization)
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
}

/// Encodes endpoint request content according to the active HTTP content type.
public enum HTTPContentEncoder {
  public static func encode<Content>(
    _ content: Content,
    as contentType: HTTPContentType,
    serialization: SerializationContext
  ) throws -> Data {
    if contentType.isJSON {
      return try encodeJSON(content, serialization: serialization)
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
    serialization: SerializationContext
  ) throws -> Data {
    guard let encodable = content as? any Encodable else {
      throw HttpContext.Error.unsupportedContentType(.json)
    }

    let encoder = JSONEncoder()
    encoder.userInfo[.serializationContext] = serialization
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
  public func session(_ session: URLSession) -> HttpContext {
    var context = self
    context.session = session
    return context
  }

  public func serialization(_ serialization: SerializationContext) -> HttpContext {
    var context = self
    context.serialization = serialization
    return context
  }

  public func errors(_ errors: HttpErrorDecoding) -> HttpContext {
    var context = self
    context.errors = errors
    return context
  }

  public func content(_ contentType: HTTPContentType) -> HttpContext {
    var context = self
    context.contentType = contentType
    return context
  }

  public func accept(_ accept: HTTPContentType) -> HttpContext {
    var context = self
    context.accept = accept
    return context
  }

  public func throwing<Failure: Decodable & Swift.Error>(
    _ failure: Failure.Type,
    for statusCode: HTTPStatusCode
  ) -> HttpContext {
    var context = self
    context.errors = context.errors.throwing(Failure.self, for: statusCode)
    return context
  }

  public func throwing<Failure: Decodable & Swift.Error>(
    _ failure: Failure.Type,
    for statusClass: HTTPStatusClass
  ) -> HttpContext {
    var context = self
    context.errors = context.errors.throwing(Failure.self, for: statusClass)
    return context
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
    if let validatable = requestBody as? any Validatable {
      try validatable.validate()
    }

    let encoder = JSONEncoder()
    encoder.userInfo[.serializationContext] = serialization
    let body = try encoder.encode(requestBody)
    return try await send(
      method: method,
      body: body,
      headers: [.contentType(.json)],
      validatesStatus: false
    )
  }

  public func response<Content>(
    for method: HTTPMethod,
    content: Content
  ) async throws -> Response<Data> {
    let contentType = self.contentType ?? .json
    let body = try HTTPContentEncoder.encode(
      content,
      as: contentType,
      serialization: serialization
    )
    return try await send(
      method: method,
      body: body,
      headers: [.contentType(contentType)],
      validatesStatus: false
    )
  }

  func makeURL() throws -> URL {
    try makeURL(from: url)
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

  func data(for method: HTTPMethod) async throws -> Response<Data> {
    try await send(method: method, body: nil)
  }

  func data<RequestBody: Encodable>(
    for method: HTTPMethod,
    json requestBody: RequestBody
  ) async throws -> Response<Data> {
    if let validatable = requestBody as? any Validatable {
      try validatable.validate()
    }

    let encoder = JSONEncoder()
    encoder.userInfo[.serializationContext] = serialization
    let body = try encoder.encode(requestBody)
    return try await send(method: method, body: body, headers: [.contentType(.json)])
  }

  func data<Content>(
    for method: HTTPMethod,
    content: Content
  ) async throws -> Response<Data> {
    let contentType = self.contentType ?? .json
    let body = try HTTPContentEncoder.encode(
      content,
      as: contentType,
      serialization: serialization
    )
    return try await send(method: method, body: body, headers: [.contentType(contentType)])
  }

  func send(
    method: HTTPMethod,
    body: Data?,
    headers additionalHeaders: [HttpHeader] = [],
    options overrideOptions: HttpOptions? = nil,
    validatesStatus: Bool = true
  ) async throws -> Response<Data> {
    let request = HttpRequest(
      method: method,
      url: url,
      headers: headers + additionalHeaders,
      body: body,
      options: overrideOptions ?? options
    )

    let transport: @Sendable (HttpRequest) async throws -> Response<Data> = { request in
      try await self.perform(request, validatesStatus: validatesStatus)
    }

    let pipeline = activeWrappers.reversed().reduce(transport) { next, wrapper in
      { request in
        try await wrapper.send(request, next: next)
      }
    }

    return try await pipeline(request)
  }

  private func perform(_ request: HttpRequest, validatesStatus: Bool) async throws -> Response<Data> {
    var urlRequest = URLRequest(url: try makeURL(from: request.url))
    urlRequest.httpMethod = request.method.rawValue
    urlRequest.httpBody = request.body
    urlRequest.setValue(
      (accept ?? .json).rawValue,
      forHTTPHeaderField: HTTPHeaderFieldName.accept.rawValue)

    request.options.apply(to: &urlRequest)

    for header in request.headers {
      urlRequest.setValue(header.value, forHTTPHeaderField: header.name.rawValue)
    }

    let (data, response) = try await session.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw Error.invalidResponse(response)
    }

    let status = HTTPStatusCode(httpResponse.statusCode)
    guard status.isSuccess || !validatesStatus else {
      if let error = try errors.decode(
        statusCode: status,
        data: data,
        response: httpResponse,
        serialization: serialization
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
    let decoder = JSONDecoder()
    decoder.userInfo[.serializationContext] = serialization
    return Response(
      body: try decoder.decode(ResponseBody.self, from: response.body),
      status: response.status,
      headers: response.headers,
      mime: response.mime,
      encoding: response.encoding,
      url: response.url
    )
  }
}

extension HttpContext {
  fileprivate var activeWrappers: [any HttpWrapper] {
    wrappers.activeKeys.compactMap { wrappers[$0] }
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
  fileprivate var httpHeaders: [HttpHeader] {
    allHeaderFields.compactMap { key, value in
      guard let name = HTTPHeaderFieldName(validating: String(describing: key)) else {
        return nil
      }

      return HttpHeader(name: name, value: String(describing: value))
    }
  }
}

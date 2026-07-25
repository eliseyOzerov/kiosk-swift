/// HTTP method value with safety and idempotency metadata.
public enum HTTPMethod: Hashable, Sendable {
  case get
  case head
  case post
  case put
  case delete
  case connect
  case options
  case trace
  case patch
  case query
  case custom(String)

  public init(_ rawValue: String) {
    switch rawValue {
    case "GET":
      self = .get
    case "HEAD":
      self = .head
    case "POST":
      self = .post
    case "PUT":
      self = .put
    case "DELETE":
      self = .delete
    case "CONNECT":
      self = .connect
    case "OPTIONS":
      self = .options
    case "TRACE":
      self = .trace
    case "PATCH":
      self = .patch
    case "QUERY":
      self = .query
    default:
      self = .custom(rawValue)
    }
  }

  public var rawValue: String {
    switch self {
    case .get:
      return "GET"
    case .head:
      return "HEAD"
    case .post:
      return "POST"
    case .put:
      return "PUT"
    case .delete:
      return "DELETE"
    case .connect:
      return "CONNECT"
    case .options:
      return "OPTIONS"
    case .trace:
      return "TRACE"
    case .patch:
      return "PATCH"
    case .query:
      return "QUERY"
    case .custom(let value):
      return value
    }
  }

  public var isSafe: Bool {
    switch self {
    case .get, .head, .options, .trace, .query:
      return true
    case .post, .put, .delete, .connect, .patch, .custom:
      return false
    }
  }

  public var isIdempotent: Bool {
    switch self {
    case .get, .head, .put, .delete, .options, .trace, .query:
      return true
    case .post, .connect, .patch, .custom:
      return false
    }
  }
}

/// Supported HTTP protocol version names.
public enum HTTPVersion: Hashable, Sendable {
  case http1_0
  case http1_1
  case http2
  case http3

  public var wireName: String {
    switch self {
    case .http1_0:
      return "HTTP/1.0"
    case .http1_1:
      return "HTTP/1.1"
    case .http2:
      return "HTTP/2"
    case .http3:
      return "HTTP/3"
    }
  }
}

/// Typed HTTP header descriptor that knows how to render a value for one header name.
public struct HttpHeaderKey<Value: Sendable>: Sendable {
  public let name: String
  fileprivate let encode: @Sendable (Value) -> String

  public init(
    _ name: String,
    encode: @escaping @Sendable (Value) -> String = { String(describing: $0) }
  ) {
    self.name = name
    self.encode = encode
  }

  public func header(_ value: Value) -> HttpHeader<Value> {
    HttpHeader(self, value)
  }

  public static func custom(_ name: String, as type: Value.Type = Value.self) -> Self {
    Self(name)
  }
}

extension HttpHeaderKey where Value == HTTPContentType {
  public static let accept = Self("Accept") { $0.rawValue }
  public static let contentType = Self("Content-Type") { $0.rawValue }
}

extension HttpHeaderKey where Value == Int {
  public static let contentLength = Self("Content-Length") { "\($0)" }
}

extension HttpHeaderKey where Value == String {
  public static let acceptEncoding = Self("Accept-Encoding")
  public static let acceptLanguage = Self("Accept-Language")
  public static let authorization = Self("Authorization")
  public static let cacheControl = Self("Cache-Control")
  public static let connection = Self("Connection")
  public static let contentEncoding = Self("Content-Encoding")
  public static let contentLanguage = Self("Content-Language")
  public static let cookie = Self("Cookie")
  public static let date = Self("Date")
  public static let etag = Self("ETag")
  public static let expect = Self("Expect")
  public static let host = Self("Host")
  public static let ifMatch = Self("If-Match")
  public static let ifModifiedSince = Self("If-Modified-Since")
  public static let ifNoneMatch = Self("If-None-Match")
  public static let ifRange = Self("If-Range")
  public static let ifUnmodifiedSince = Self("If-Unmodified-Since")
  public static let lastModified = Self("Last-Modified")
  public static let link = Self("Link")
  public static let location = Self("Location")
  public static let origin = Self("Origin")
  public static let proxyAuthenticate = Self("Proxy-Authenticate")
  public static let proxyAuthorization = Self("Proxy-Authorization")
  public static let range = Self("Range")
  public static let referer = Self("Referer")
  public static let retryAfter = Self("Retry-After")
  public static let server = Self("Server")
  public static let setCookie = Self("Set-Cookie")
  public static let trailer = Self("Trailer")
  public static let transferEncoding = Self("Transfer-Encoding")
  public static let upgrade = Self("Upgrade")
  public static let userAgent = Self("User-Agent")
  public static let vary = Self("Vary")
  public static let via = Self("Via")
  public static let wwwAuthenticate = Self("WWW-Authenticate")
}

/// Typed HTTP header pair before it is rendered for transport.
public struct HttpHeader<Value: Sendable>: Sendable {
  public let key: HttpHeaderKey<Value>
  public let value: Value

  public init(_ key: HttpHeaderKey<Value>, _ value: Value) {
    self.key = key
    self.value = value
  }

  public var erased: AnyHttpHeader {
    AnyHttpHeader(name: key.name, value: key.encode(value))
  }
}

/// Erased name/value HTTP header pair ready to store on a request or response.
public struct AnyHttpHeader: Hashable, Sendable {
  public let name: String
  public let value: String

  public init(name: String, value: String) {
    self.name = name
    self.value = value
  }

  public static func == (lhs: AnyHttpHeader, rhs: AnyHttpHeader) -> Bool {
    lhs.name.lowercased() == rhs.name.lowercased() && lhs.value == rhs.value
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name.lowercased())
    hasher.combine(value)
  }
}

/// Validated HTTP content type wrapper.
public struct HTTPContentType: Hashable, ExpressibleByStringLiteral, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    precondition(
      Self.isValidContentType(rawValue), "HTTP content types must include a type and subtype.")
    self.rawValue = rawValue
  }

  public init?(validating rawValue: String) {
    guard Self.isValidContentType(rawValue) else {
      return nil
    }
    self.rawValue = rawValue
  }

  public init(stringLiteral value: String) {
    self.init(value)
  }
}

extension HTTPContentType {
  public static let any = HTTPContentType("*/*")
  public static let json = HTTPContentType("application/json")
  public static let problem = HTTPContentType("application/problem+json")
  public static let form = HTTPContentType("application/x-www-form-urlencoded")
  public static let binary = HTTPContentType("application/octet-stream")
  public static let html = HTTPContentType("text/html")
  public static let jpeg = HTTPContentType("image/jpeg")
  public static let png = HTTPContentType("image/png")
  public static let text = HTTPContentType("text/plain")
  public static let utf8 = HTTPContentType("text/plain; charset=utf-8")

  public static func multipart(boundary: String) -> HTTPContentType {
    HTTPContentType("multipart/form-data; boundary=\(boundary)")
  }
}

extension HTTPContentType {
  public var isJSON: Bool {
    rawValue == Self.json.rawValue || rawValue.hasSuffix("+json")
  }

  public var isForm: Bool {
    rawValue == Self.form.rawValue
  }

  public var isBinary: Bool {
    rawValue == Self.binary.rawValue
  }

  public var isText: Bool {
    rawValue.hasPrefix("text/")
  }

  public var isMultipart: Bool {
    rawValue.hasPrefix("multipart/")
  }

  public var multipartBoundary: String? {
    let parameters = rawValue.split(separator: ";").dropFirst()
    for parameter in parameters {
      let pair = parameter.split(separator: "=", maxSplits: 1).map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      if pair.count == 2,
        pair[0].lowercased() == "boundary"
      {
        return pair[1]
      }
    }

    return nil
  }
}

extension HTTPContentType {
  fileprivate static func isValidContentType(_ value: String) -> Bool {
    if value == "*/*" {
      return true
    }

    let parts = value.split(separator: ";", maxSplits: 1)
    guard let essence = parts.first else {
      return false
    }

    let typeParts = essence.split(separator: "/", maxSplits: 1)
    return typeParts.count == 2 && !typeParts[0].isEmpty && !typeParts[1].isEmpty
  }
}

/// HTTP text encoding name wrapper.
public struct HTTPTextEncodingName: Hashable, ExpressibleByStringLiteral, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    precondition(!rawValue.isEmpty, "HTTP text encoding names must be non-empty.")
    self.rawValue = rawValue
  }

  public init?(validating rawValue: String) {
    guard !rawValue.isEmpty else {
      return nil
    }
    self.rawValue = rawValue
  }

  public init(stringLiteral value: String) {
    self.init(value)
  }
}

extension HTTPTextEncodingName {
  public static let ascii = HTTPTextEncodingName("us-ascii")
  public static let isoLatin1 = HTTPTextEncodingName("iso-8859-1")
  public static let utf8 = HTTPTextEncodingName("utf-8")
  public static let utf16 = HTTPTextEncodingName("utf-16")
}

/// HTTP status family.
public enum HTTPStatusClass: Hashable, Sendable {
  case informational
  case success
  case redirection
  case clientError
  case serverError
}

/// Validated HTTP status code with status family helpers.
public struct HTTPStatusCode: Hashable, Comparable, ExpressibleByIntegerLiteral, Sendable {
  public let rawValue: Int

  public init(_ rawValue: Int) {
    precondition(
      (100...599).contains(rawValue),
      "HTTP status codes must be three-digit values from 100 through 599.")
    self.rawValue = rawValue
  }

  public init(integerLiteral value: Int) {
    self.init(value)
  }

  public static func < (lhs: HTTPStatusCode, rhs: HTTPStatusCode) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

extension HTTPStatusCode {
  public var statusClass: HTTPStatusClass {
    switch rawValue {
    case 100...199:
      return .informational
    case 200...299:
      return .success
    case 300...399:
      return .redirection
    case 400...499:
      return .clientError
    default:
      return .serverError
    }
  }

  public var isSuccess: Bool {
    statusClass == .success
  }

  public var reasonPhrase: String {
    switch self {
    case .continue:
      return "Continue"
    case .switchingProtocols:
      return "Switching Protocols"
    case .processing:
      return "Processing"
    case .earlyHints:
      return "Early Hints"
    case .ok:
      return "OK"
    case .created:
      return "Created"
    case .accepted:
      return "Accepted"
    case .nonAuthoritativeInformation:
      return "Non-Authoritative Information"
    case .noContent:
      return "No Content"
    case .resetContent:
      return "Reset Content"
    case .partialContent:
      return "Partial Content"
    case .multipleChoices:
      return "Multiple Choices"
    case .movedPermanently:
      return "Moved Permanently"
    case .found:
      return "Found"
    case .seeOther:
      return "See Other"
    case .notModified:
      return "Not Modified"
    case .temporaryRedirect:
      return "Temporary Redirect"
    case .permanentRedirect:
      return "Permanent Redirect"
    case .badRequest:
      return "Bad Request"
    case .unauthorized:
      return "Unauthorized"
    case .paymentRequired:
      return "Payment Required"
    case .forbidden:
      return "Forbidden"
    case .notFound:
      return "Not Found"
    case .methodNotAllowed:
      return "Method Not Allowed"
    case .notAcceptable:
      return "Not Acceptable"
    case .proxyAuthenticationRequired:
      return "Proxy Authentication Required"
    case .requestTimeout:
      return "Request Timeout"
    case .conflict:
      return "Conflict"
    case .gone:
      return "Gone"
    case .lengthRequired:
      return "Length Required"
    case .preconditionFailed:
      return "Precondition Failed"
    case .contentTooLarge:
      return "Content Too Large"
    case .uriTooLong:
      return "URI Too Long"
    case .unsupportedMediaType:
      return "Unsupported Media Type"
    case .rangeNotSatisfiable:
      return "Range Not Satisfiable"
    case .expectationFailed:
      return "Expectation Failed"
    case .misdirectedRequest:
      return "Misdirected Request"
    case .unprocessableContent:
      return "Unprocessable Content"
    case .upgradeRequired:
      return "Upgrade Required"
    case .preconditionRequired:
      return "Precondition Required"
    case .tooManyRequests:
      return "Too Many Requests"
    case .requestHeaderFieldsTooLarge:
      return "Request Header Fields Too Large"
    case .unavailableForLegalReasons:
      return "Unavailable For Legal Reasons"
    case .internalServerError:
      return "Internal Server Error"
    case .notImplemented:
      return "Not Implemented"
    case .badGateway:
      return "Bad Gateway"
    case .serviceUnavailable:
      return "Service Unavailable"
    case .gatewayTimeout:
      return "Gateway Timeout"
    case .httpVersionNotSupported:
      return "HTTP Version Not Supported"
    case .variantAlsoNegotiates:
      return "Variant Also Negotiates"
    case .insufficientStorage:
      return "Insufficient Storage"
    case .loopDetected:
      return "Loop Detected"
    case .notExtended:
      return "Not Extended"
    case .networkAuthenticationRequired:
      return "Network Authentication Required"
    default:
      return "Unknown"
    }
  }
}

extension HTTPStatusCode {
  public static let `continue` = HTTPStatusCode(100)
  public static let switchingProtocols = HTTPStatusCode(101)
  public static let processing = HTTPStatusCode(102)
  public static let earlyHints = HTTPStatusCode(103)

  public static let ok = HTTPStatusCode(200)
  public static let created = HTTPStatusCode(201)
  public static let accepted = HTTPStatusCode(202)
  public static let nonAuthoritativeInformation = HTTPStatusCode(203)
  public static let noContent = HTTPStatusCode(204)
  public static let resetContent = HTTPStatusCode(205)
  public static let partialContent = HTTPStatusCode(206)

  public static let multipleChoices = HTTPStatusCode(300)
  public static let movedPermanently = HTTPStatusCode(301)
  public static let found = HTTPStatusCode(302)
  public static let seeOther = HTTPStatusCode(303)
  public static let notModified = HTTPStatusCode(304)
  public static let temporaryRedirect = HTTPStatusCode(307)
  public static let permanentRedirect = HTTPStatusCode(308)

  public static let badRequest = HTTPStatusCode(400)
  public static let unauthorized = HTTPStatusCode(401)
  public static let paymentRequired = HTTPStatusCode(402)
  public static let forbidden = HTTPStatusCode(403)
  public static let notFound = HTTPStatusCode(404)
  public static let methodNotAllowed = HTTPStatusCode(405)
  public static let notAcceptable = HTTPStatusCode(406)
  public static let proxyAuthenticationRequired = HTTPStatusCode(407)
  public static let requestTimeout = HTTPStatusCode(408)
  public static let conflict = HTTPStatusCode(409)
  public static let gone = HTTPStatusCode(410)
  public static let lengthRequired = HTTPStatusCode(411)
  public static let preconditionFailed = HTTPStatusCode(412)
  public static let contentTooLarge = HTTPStatusCode(413)
  public static let uriTooLong = HTTPStatusCode(414)
  public static let unsupportedMediaType = HTTPStatusCode(415)
  public static let rangeNotSatisfiable = HTTPStatusCode(416)
  public static let expectationFailed = HTTPStatusCode(417)
  public static let misdirectedRequest = HTTPStatusCode(421)
  public static let unprocessableContent = HTTPStatusCode(422)
  public static let upgradeRequired = HTTPStatusCode(426)
  public static let preconditionRequired = HTTPStatusCode(428)
  public static let tooManyRequests = HTTPStatusCode(429)
  public static let requestHeaderFieldsTooLarge = HTTPStatusCode(431)
  public static let unavailableForLegalReasons = HTTPStatusCode(451)

  public static let internalServerError = HTTPStatusCode(500)
  public static let notImplemented = HTTPStatusCode(501)
  public static let badGateway = HTTPStatusCode(502)
  public static let serviceUnavailable = HTTPStatusCode(503)
  public static let gatewayTimeout = HTTPStatusCode(504)
  public static let httpVersionNotSupported = HTTPStatusCode(505)
  public static let variantAlsoNegotiates = HTTPStatusCode(506)
  public static let insufficientStorage = HTTPStatusCode(507)
  public static let loopDetected = HTTPStatusCode(508)
  public static let notExtended = HTTPStatusCode(510)
  public static let networkAuthenticationRequired = HTTPStatusCode(511)
}

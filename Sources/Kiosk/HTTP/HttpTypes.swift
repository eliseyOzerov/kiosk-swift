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

/// Case-insensitive validated HTTP header field name.
public struct HTTPHeaderFieldName: Hashable, ExpressibleByStringLiteral, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    precondition(Self.isValidToken(rawValue), "HTTP field names must be non-empty RFC tokens.")
    self.rawValue = rawValue
  }

  public init?(validating rawValue: String) {
    guard Self.isValidToken(rawValue) else {
      return nil
    }
    self.rawValue = rawValue
  }

  public init(stringLiteral value: String) {
    self.init(value)
  }

  public static func == (lhs: HTTPHeaderFieldName, rhs: HTTPHeaderFieldName) -> Bool {
    lhs.rawValue.lowercased() == rhs.rawValue.lowercased()
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue.lowercased())
  }
}

extension HTTPHeaderFieldName {
  public static let accept = HTTPHeaderFieldName("Accept")
  public static let acceptEncoding = HTTPHeaderFieldName("Accept-Encoding")
  public static let acceptLanguage = HTTPHeaderFieldName("Accept-Language")
  public static let allow = HTTPHeaderFieldName("Allow")
  public static let authorization = HTTPHeaderFieldName("Authorization")
  public static let cacheControl = HTTPHeaderFieldName("Cache-Control")
  public static let connection = HTTPHeaderFieldName("Connection")
  public static let contentEncoding = HTTPHeaderFieldName("Content-Encoding")
  public static let contentLanguage = HTTPHeaderFieldName("Content-Language")
  public static let contentLength = HTTPHeaderFieldName("Content-Length")
  public static let contentLocation = HTTPHeaderFieldName("Content-Location")
  public static let contentRange = HTTPHeaderFieldName("Content-Range")
  public static let contentType = HTTPHeaderFieldName("Content-Type")
  public static let cookie = HTTPHeaderFieldName("Cookie")
  public static let date = HTTPHeaderFieldName("Date")
  public static let etag = HTTPHeaderFieldName("ETag")
  public static let expect = HTTPHeaderFieldName("Expect")
  public static let host = HTTPHeaderFieldName("Host")
  public static let ifMatch = HTTPHeaderFieldName("If-Match")
  public static let ifModifiedSince = HTTPHeaderFieldName("If-Modified-Since")
  public static let ifNoneMatch = HTTPHeaderFieldName("If-None-Match")
  public static let ifRange = HTTPHeaderFieldName("If-Range")
  public static let ifUnmodifiedSince = HTTPHeaderFieldName("If-Unmodified-Since")
  public static let lastModified = HTTPHeaderFieldName("Last-Modified")
  public static let link = HTTPHeaderFieldName("Link")
  public static let location = HTTPHeaderFieldName("Location")
  public static let origin = HTTPHeaderFieldName("Origin")
  public static let proxyAuthenticate = HTTPHeaderFieldName("Proxy-Authenticate")
  public static let proxyAuthorization = HTTPHeaderFieldName("Proxy-Authorization")
  public static let range = HTTPHeaderFieldName("Range")
  public static let referer = HTTPHeaderFieldName("Referer")
  public static let retryAfter = HTTPHeaderFieldName("Retry-After")
  public static let server = HTTPHeaderFieldName("Server")
  public static let setCookie = HTTPHeaderFieldName("Set-Cookie")
  public static let trailer = HTTPHeaderFieldName("Trailer")
  public static let transferEncoding = HTTPHeaderFieldName("Transfer-Encoding")
  public static let upgrade = HTTPHeaderFieldName("Upgrade")
  public static let userAgent = HTTPHeaderFieldName("User-Agent")
  public static let vary = HTTPHeaderFieldName("Vary")
  public static let via = HTTPHeaderFieldName("Via")
  public static let wwwAuthenticate = HTTPHeaderFieldName("WWW-Authenticate")
}

extension HTTPHeaderFieldName {
  fileprivate static func isValidToken(_ token: String) -> Bool {
    !token.isEmpty && token.utf8.allSatisfy(isTokenByte)
  }

  fileprivate static func isTokenByte(_ byte: UInt8) -> Bool {
    switch byte {
    case 48...57, 65...90, 97...122:
      return true
    case 33, 35, 36, 37, 38, 39, 42, 43, 45, 46, 94, 95, 96, 124, 126:
      return true
    default:
      return false
    }
  }
}

/// Name/value HTTP header pair.
public struct HttpHeader: Hashable, Sendable {
  public let name: HTTPHeaderFieldName
  public let value: String

  public init(name: HTTPHeaderFieldName, value: String) {
    self.name = name
    self.value = value
  }
}

extension HttpHeader {
  public static func accept(_ contentType: HTTPContentType) -> HttpHeader {
    HttpHeader(name: .accept, value: contentType.rawValue)
  }

  public static func authorization(_ value: String) -> HttpHeader {
    HttpHeader(name: .authorization, value: value)
  }

  public static func contentLength(_ value: Int) -> HttpHeader {
    HttpHeader(name: .contentLength, value: "\(value)")
  }

  public static func contentType(_ contentType: HTTPContentType) -> HttpHeader {
    HttpHeader(name: .contentType, value: contentType.rawValue)
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

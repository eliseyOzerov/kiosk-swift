import Foundation

/// Validated URL scheme wrapper with common scheme constants.
public struct UrlScheme: Hashable, ExpressibleByStringLiteral, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    let value = rawValue.lowercased()
    precondition(
      Self.isValidScheme(value),
      "URL schemes must start with a letter and contain only letters, digits, '+', '-', or '.'.")
    self.rawValue = value
  }

  public init(stringLiteral value: String) {
    self.init(value)
  }
}

extension UrlScheme {
  public static let about = UrlScheme("about")
  public static let blob = UrlScheme("blob")
  public static let data = UrlScheme("data")
  public static let `file` = UrlScheme("file")
  public static let ftp = UrlScheme("ftp")
  public static let geo = UrlScheme("geo")
  public static let git = UrlScheme("git")
  public static let http = UrlScheme("http")
  public static let https = UrlScheme("https")
  public static let ipfs = UrlScheme("ipfs")
  public static let ipns = UrlScheme("ipns")
  public static let magnet = UrlScheme("magnet")
  public static let mailto = UrlScheme("mailto")
  public static let maps = UrlScheme("maps")
  public static let openid = UrlScheme("openid")
  public static let otpauth = UrlScheme("otpauth")
  public static let payto = UrlScheme("payto")
  public static let sftp = UrlScheme("sftp")
  public static let sms = UrlScheme("sms")
  public static let ssh = UrlScheme("ssh")
  public static let tel = UrlScheme("tel")
  public static let urn = UrlScheme("urn")
  public static let webcal = UrlScheme("webcal")
  public static let ws = UrlScheme("ws")
  public static let wss = UrlScheme("wss")
  public static let xmpp = UrlScheme("xmpp")
}

extension UrlScheme {
  fileprivate static func isValidScheme(_ value: String) -> Bool {
    guard let first = value.utf8.first, isAlpha(first) else {
      return false
    }

    return value.utf8.dropFirst().allSatisfy { byte in
      isAlpha(byte) || isDigit(byte) || byte == 43 || byte == 45 || byte == 46
    }
  }

  fileprivate static func isAlpha(_ byte: UInt8) -> Bool {
    (65...90).contains(byte) || (97...122).contains(byte)
  }

  fileprivate static func isDigit(_ byte: UInt8) -> Bool {
    (48...57).contains(byte)
  }
}

/// Validated URL port wrapper with common service port constants.
public struct UrlPort: Hashable, Comparable, ExpressibleByIntegerLiteral, Sendable {
  public let rawValue: Int

  public init(_ rawValue: Int) {
    precondition((0...65_535).contains(rawValue), "URL ports must be values from 0 through 65535.")
    self.rawValue = rawValue
  }

  public init(integerLiteral value: Int) {
    self.init(value)
  }

  public static func < (lhs: UrlPort, rhs: UrlPort) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

extension UrlPort {
  public static let ftp = UrlPort(21)
  public static let ssh = UrlPort(22)
  public static let sftp = UrlPort(22)
  public static let smtp = UrlPort(25)
  public static let dns = UrlPort(53)
  public static let http = UrlPort(80)
  public static let pop3 = UrlPort(110)
  public static let imap = UrlPort(143)
  public static let ldap = UrlPort(389)
  public static let https = UrlPort(443)
  public static let smtps = UrlPort(465)
  public static let submission = UrlPort(587)
  public static let ldaps = UrlPort(636)
  public static let imaps = UrlPort(993)
  public static let pop3s = UrlPort(995)
  public static let postgresql = UrlPort(5432)
  public static let redis = UrlPort(6379)
  public static let mongodb = UrlPort(27017)
  public static let development = UrlPort(3000)
  public static let flask = UrlPort(5000)
  public static let vite = UrlPort(5173)
  public static let django = UrlPort(8000)
  public static let alternateHTTP = UrlPort(8080)
  public static let alternateHTTPS = UrlPort(8443)
}

/// Protocol for values that can render as URL path components.
public protocol UrlPathComponent: Sendable {
  var urlPathComponent: String { get }
}

extension String: UrlPathComponent {
  public var urlPathComponent: String { self }
}

extension Substring: UrlPathComponent {
  public var urlPathComponent: String { String(self) }
}

extension Int: UrlPathComponent {
  public var urlPathComponent: String { String(self) }
}

extension UUID: UrlPathComponent {
  public var urlPathComponent: String { uuidString }
}

extension Date: UrlPathComponent {
  public var urlPathComponent: String {
    ISO8601DateFormatter().string(from: self)
  }
}

/// URL query item with a non-empty name and optional value.
public struct UrlQueryItem: Hashable, Sendable {
  public let name: String
  public let value: String?

  public init(name: String, value: String?) {
    precondition(!name.isEmpty, "URL query item names must be non-empty.")
    self.name = name
    self.value = value
  }

  public init<Value: UrlQueryValue>(name: String, value: Value) {
    self.init(name: name, value: value.urlQueryValue)
  }
}

/// Protocol for values that can render as URL query values.
public protocol UrlQueryValue {
  var urlQueryValue: String? { get }
}

extension String: UrlQueryValue {
  public var urlQueryValue: String? { self }
}

extension Substring: UrlQueryValue {
  public var urlQueryValue: String? { String(self) }
}

extension Int: UrlQueryValue {
  public var urlQueryValue: String? { String(self) }
}

extension Double: UrlQueryValue {
  public var urlQueryValue: String? { String(self) }
}

extension Bool: UrlQueryValue {
  public var urlQueryValue: String? { self ? "true" : "false" }
}

extension UUID: UrlQueryValue {
  public var urlQueryValue: String? { uuidString }
}

extension Date: UrlQueryValue {
  public var urlQueryValue: String? {
    ISO8601DateFormatter().string(from: self)
  }
}

extension Optional: UrlQueryValue where Wrapped: UrlQueryValue {
  public var urlQueryValue: String? {
    switch self {
    case .some(let value):
      return value.urlQueryValue
    case .none:
      return nil
    }
  }
}

/// Fluent builder for URLs and HTTP/WebSocket request contexts.
public struct UrlBuilder: Sendable {
  public var scheme: UrlScheme
  public var host: String?
  public var port: UrlPort?
  public var path: [UrlPathComponent]
  public var query: [UrlQueryItem]

  public init(
    scheme: UrlScheme = .https,
    host: String? = nil,
    port: UrlPort? = nil,
    path: [UrlPathComponent] = [],
    query: [UrlQueryItem] = []
  ) {
    self.scheme = scheme
    self.host = host
    self.port = port
    self.path = path
    self.query = query
  }

  public init(_ host: String) {
    self.init(host: host)
  }

  public init(_ url: URL) {
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let scheme = components?.scheme.map { UrlScheme($0) } ?? .https
    let host = components?.host
    let port = components?.port.map { UrlPort($0) }
    let path: [UrlPathComponent] = (components?.percentEncodedPath ?? "")
      .split(separator: "/")
      .map { component in
        let value = String(component)
        return value.removingPercentEncoding ?? value
      }
    let query = components?.queryItems?.map {
      UrlQueryItem(name: $0.name, value: $0.value)
    } ?? []

    self.init(
      scheme: scheme,
      host: host,
      port: port,
      path: path,
      query: query
    )
  }
}

extension UrlBuilder {
  public enum Error: Swift.Error {
    case missingHost
    case invalidURL
  }

  public static func host(_ host: String) -> UrlBuilder {
    UrlBuilder(host)
  }

  public func build() throws -> URL {
    guard let host, !host.isEmpty else {
      throw Error.missingHost
    }

    var components = URLComponents()
    components.scheme = scheme.rawValue
    components.host = host
    components.port = port?.rawValue
    components.percentEncodedPath = percentEncodedPath
    components.queryItems = query.isEmpty ? nil : query.map(\.urlQueryItem)

    guard let url = components.url else {
      throw Error.invalidURL
    }

    return url
  }
}

extension UrlBuilder {
  public func scheme(_ scheme: UrlScheme) -> Self {
    var builder = self
    builder.scheme = scheme
    return builder
  }

  public func host(_ host: String?) -> Self {
    var builder = self
    builder.host = host
    return builder
  }

  public func port(_ port: UrlPort?) -> Self {
    var builder = self
    builder.port = port
    return builder
  }

  public func path(_ path: [UrlPathComponent]) -> Self {
    var builder = self
    builder.path = path
    return builder
  }

  public func query(_ query: [UrlQueryItem]) -> Self {
    var builder = self
    builder.query = query
    return builder
  }

  public func adding(path component: UrlPathComponent) -> Self {
    var builder = self
    builder.path.append(component)
    return builder
  }

  public func adding(query item: UrlQueryItem) -> Self {
    var builder = self
    builder.query.append(item)
    return builder
  }

  public func http(tls: Bool = true, session: URLSession = .shared) -> HttpContext {
    HttpContext(session: session, url: scheme(tls ? .https : .http))
  }

  public func ws(tls: Bool = true, session: URLSession = .shared) -> WsContext {
    WsContext(session: session, url: scheme(tls ? .wss : .ws))
  }
}

extension UrlBuilder {
  var percentEncodedPath: String {
    let path =
      path
      .map { component in
        let value = component.urlPathComponent
        return value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
      }
      .joined(separator: "/")

    return path.isEmpty ? "" : "/\(path)"
  }
}

extension UrlQueryItem {
  fileprivate var urlQueryItem: URLQueryItem {
    URLQueryItem(name: name, value: value)
  }
}

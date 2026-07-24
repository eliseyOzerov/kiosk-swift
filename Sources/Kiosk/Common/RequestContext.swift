/// Shared fluent URL, header, and options contract for request contexts.
public protocol RequestContext {
  associatedtype Options

  var url: UrlBuilder { get set }
  var headers: [HttpHeader] { get set }
  var options: Options { get set }
}

extension RequestContext {
  public func url(_ url: UrlBuilder) -> Self {
    var context = self
    context.url = url
    return context
  }

  public func scheme(_ scheme: UrlScheme) -> Self {
    var context = self
    context.url = context.url.scheme(scheme)
    return context
  }

  public func host(_ host: String?) -> Self {
    var context = self
    context.url = context.url.host(host)
    return context
  }

  public func port(_ port: UrlPort?) -> Self {
    var context = self
    context.url = context.url.port(port)
    return context
  }

  public func path(_ path: [UrlPathComponent]) -> Self {
    var context = self
    context.url = context.url.path(path)
    return context
  }

  public func query(_ query: [UrlQueryItem]) -> Self {
    var context = self
    context.url = context.url.query(query)
    return context
  }

  public func headers(_ headers: [HttpHeader]) -> Self {
    var context = self
    context.headers = headers
    return context
  }

  public func options(_ options: Options) -> Self {
    var context = self
    context.options = options
    return context
  }

  public func adding(path component: UrlPathComponent) -> Self {
    var context = self
    context.url = context.url.adding(path: component)
    return context
  }

  public func adding(query item: UrlQueryItem) -> Self {
    var context = self
    context.url = context.url.adding(query: item)
    return context
  }

  public func adding(query items: [UrlQueryItem]) -> Self {
    var context = self
    for item in items {
      context.url = context.url.adding(query: item)
    }
    return context
  }

  public func adding(header: HttpHeader) -> Self {
    var context = self
    context.headers.append(header)
    return context
  }

  public func adding(headers: [HttpHeader]) -> Self {
    var context = self
    context.headers.append(contentsOf: headers)
    return context
  }
}

/// Named key used to register and activate request wrappers.
public struct WrapperKey: Hashable, ExpressibleByStringLiteral, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: String) {
    self.init(value)
  }
}

extension WrapperKey {
  public static let auth = WrapperKey("auth")
  public static let logging = WrapperKey("logging")
}

/// Registry storing wrappers and their active execution order.
public struct WrapperRegistry<Wrapper: Sendable>: Sendable {
  private var storage: [WrapperKey: Wrapper]
  public private(set) var activeKeys: [WrapperKey]

  public init(_ storage: [WrapperKey: Wrapper] = [:], activeKeys: [WrapperKey] = []) {
    self.storage = storage
    self.activeKeys = activeKeys
  }

  public subscript(_ key: WrapperKey) -> Wrapper? {
    get {
      storage[key]
    }
    set {
      storage[key] = newValue
    }
  }

  public mutating func activate(_ key: WrapperKey) {
    if !activeKeys.contains(key) {
      activeKeys.append(key)
    }
  }

  public mutating func deactivate(_ key: WrapperKey) {
    activeKeys.removeAll { $0 == key }
  }

  public mutating func deactivateAll() {
    activeKeys.removeAll()
  }
}

/// Protocol for request contexts that can activate or deactivate wrappers.
public protocol WrapperContext {
  associatedtype Wrapper: Sendable

  var wrappers: WrapperRegistry<Wrapper> { get set }
}

extension WrapperContext {
  public func register(_ key: WrapperKey, _ wrapper: Wrapper) -> Self {
    var context = self
    context.wrappers[key] = wrapper
    return context
  }

  public func wrap(_ key: WrapperKey, _ wrapper: Wrapper? = nil, activate: Bool = true) -> Self {
    var context = self
    if let wrapper {
      context.wrappers[key] = wrapper
    }
    if activate {
      context.wrappers.activate(key)
    }
    return context
  }

  public func unwrap(_ key: WrapperKey) -> Self {
    var context = self
    context.wrappers.deactivate(key)
    return context
  }

  public func unwrapped() -> Self {
    var context = self
    context.wrappers.deactivateAll()
    return context
  }
}

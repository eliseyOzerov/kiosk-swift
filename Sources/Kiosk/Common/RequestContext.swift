/// Shared fluent URL, header, and options contract for request contexts.
public protocol RequestContext {
  associatedtype Options

  var url: UrlBuilder { get set }
  var headers: HttpHeaderStorage { get set }
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

  public func headers(_ headers: HttpHeaderStorage) -> Self {
    var context = self
    context.headers = headers
    return context
  }

  public func headers(_ headers: [AnyHttpHeader]) -> Self {
    self.headers(HttpHeaderStorage(headers))
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

  public func adding(header: AnyHttpHeader) -> Self {
    var context = self
    context.headers.set(header)
    return context
  }

  public func adding<Value: Sendable>(header: HttpHeader<Value>) -> Self {
    adding(header: header.erased)
  }

  public func set(header: AnyHttpHeader) -> Self {
    adding(header: header)
  }

  public func set<Value: Sendable>(header: HttpHeader<Value>) -> Self {
    adding(header: header)
  }

  public func adding(headers: [AnyHttpHeader]) -> Self {
    var context = self
    context.headers.set(headers)
    return context
  }

  public func adding(headers: HttpHeaderStorage) -> Self {
    var context = self
    context.headers.set(headers)
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
  private var factories: [WrapperKey: @Sendable () -> Wrapper]
  public private(set) var activeKeys: [WrapperKey]
  private var inactiveKeys: Set<WrapperKey>
  private var deactivatesAll: Bool

  public init(_ storage: [WrapperKey: Wrapper] = [:], activeKeys: [WrapperKey] = []) {
    self.storage = storage
    self.factories = [:]
    self.activeKeys = activeKeys
    self.inactiveKeys = []
    self.deactivatesAll = false
  }

  public subscript(_ key: WrapperKey) -> Wrapper? {
    get {
      storage[key]
    }
    set {
      storage[key] = newValue
      factories[key] = nil
    }
  }

  public mutating func set(_ key: WrapperKey, factory: @escaping @Sendable () -> Wrapper) {
    storage[key] = nil
    factories[key] = factory
  }

  func resolve(_ key: WrapperKey) -> Wrapper? {
    storage[key] ?? factories[key]?()
  }

  public mutating func activate(_ key: WrapperKey) {
    inactiveKeys.remove(key)
    deactivatesAll = false
    if !activeKeys.contains(key) {
      activeKeys.append(key)
    }
  }

  public mutating func deactivate(_ key: WrapperKey) {
    activeKeys.removeAll { $0 == key }
    inactiveKeys.insert(key)
  }

  public mutating func deactivateAll() {
    activeKeys.removeAll()
    inactiveKeys.removeAll()
    deactivatesAll = true
  }

  func merging(_ local: WrapperRegistry<Wrapper>) -> WrapperRegistry<Wrapper> {
    var merged = self

    for (key, wrapper) in local.storage {
      merged.storage[key] = wrapper
      merged.factories[key] = nil
    }

    for (key, factory) in local.factories {
      merged.storage[key] = nil
      merged.factories[key] = factory
    }

    if local.deactivatesAll {
      merged.activeKeys.removeAll()
    }

    for key in local.inactiveKeys {
      merged.activeKeys.removeAll { $0 == key }
    }

    for key in local.activeKeys where !merged.activeKeys.contains(key) {
      merged.activeKeys.append(key)
    }

    return merged
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

/// Marks an API method parameter as a query value.
@propertyWrapper
public struct Query<Value> {
  public var wrappedValue: Value
  public let name: String?

  public init(wrappedValue: Value, _ name: String? = nil) {
    self.wrappedValue = wrappedValue
    self.name = name
  }
}

/// Type-erased query property wrapper used by `UrlQueryEncoder`.
protocol AnyQuery {
  var queryName: String? { get }
  func queryItem(named name: String) -> UrlQueryItem?
}

extension Query: AnyQuery {
  var queryName: String? { name }

  func queryItem(named name: String) -> UrlQueryItem? {
    guard let queryValue = UrlQueryEncoder.queryValue(wrappedValue) else {
      return nil
    }

    return UrlQueryItem(name: self.name ?? name, value: queryValue)
  }
}

/// Marks an API method parameter as the request content.
@propertyWrapper
public struct Content<Value> {
  public var wrappedValue: Value

  public init(wrappedValue: Value) {
    self.wrappedValue = wrappedValue
  }
}

/// Provides HTTP content field-name overrides for generated endpoint payloads.
public protocol HTTPContentKeyProviding {
  static var contentKeys: [String: String] { get }
}

import Foundation

/// Encodes structured query values into URL query items for endpoint macros.
public enum UrlQueryEncoder {
  public static func encode<Value>(
    _ value: Value,
    keys: [String: String] = [:]
  ) -> [UrlQueryItem] {
    let children = Array(Mirror(reflecting: value).children)
    return children.compactMap { child -> UrlQueryItem? in
      guard let label = child.label,
        !label.hasPrefix("__")
      else {
        return nil
      }

      let field = label.hasPrefix("_") ? String(label.dropFirst()) : label
      if let query = child.value as? AnyQuery {
        return query.queryItem(named: keys[field] ?? query.queryName ?? field)
      }

      guard let value = queryValue(child.value) else {
        return nil
      }

      return UrlQueryItem(name: keys[field] ?? field, value: value)
    }
  }

  static func queryValue(_ value: Any) -> String? {
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
      guard let child = mirror.children.first else {
        return nil
      }

      return queryValue(child.value)
    }

    return (value as? any UrlQueryValue)?.urlQueryValue
  }
}

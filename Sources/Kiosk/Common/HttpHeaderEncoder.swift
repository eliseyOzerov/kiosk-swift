/// Encodes structured endpoint header values into HTTP headers.
public enum HttpHeaderEncoder {
  public static func encode<Value>(
    _ value: Value,
    names: [String: String] = [:]
  ) -> [AnyHttpHeader] {
    let children = Array(Mirror(reflecting: value).children)
    return children.compactMap { child -> AnyHttpHeader? in
      guard let label = child.label,
        !label.hasPrefix("__"),
        let value = headerValue(child.value)
      else {
        return nil
      }

      let field = label.hasPrefix("_") ? String(label.dropFirst()) : label
      return AnyHttpHeader(name: names[field] ?? field, value: value)
    }
  }

  static func headerValue(_ value: Any) -> String? {
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
      guard let child = mirror.children.first else {
        return nil
      }

      return headerValue(child.value)
    }

    if let contentType = value as? HTTPContentType {
      return contentType.rawValue
    }

    return String(describing: value)
  }
}

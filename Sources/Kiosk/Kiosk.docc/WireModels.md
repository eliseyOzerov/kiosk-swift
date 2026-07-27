# Wire Models

Use wire DTOs to keep transport encoding local to the API client.

## Overview

`@Wire` generates `Codable` support using Kiosk wire metadata. Use it for request and response DTOs that belong to the API boundary.

```swift
@Wire
struct UserProfile {
  let id: Int

  @Field("display_name")
  let displayName: String

  @Format(.iso8601)
  let createdAt: Date
}
```

## Scoped Policy

Wire policy can be configured on the API, route, or endpoint with macros:

```swift
@Api(.host("api.example.com"))
@Codec(.json)
@Rename(.snakeCase)
@Format(Date.self, .iso8601)
@Default([String].self, [])
struct StoreAPI {}
```

The same policy can be configured at runtime through generated proxy methods:

```swift
let api = StoreAPI("api.example.com")
  .codec(.json)
  .rename(.snakeCase)
  .format(Date.self, .iso8601)
  .wireDefault([String].self, [])
```

## Field Metadata

Use `@Field` for explicit wire names, `@Format` for per-property value formats, and `@Default` for decode fallbacks.

```swift
@Wire
struct Page {
  @Default(1)
  var number: Int

  var items: [Item]
}
```

`@Field` takes priority over scoped renaming. Property-level `@Format` and `@Default` take priority over scoped type rules.

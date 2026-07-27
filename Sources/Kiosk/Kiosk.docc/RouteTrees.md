# Route Trees

Use nested Swift types to make REST paths discoverable.

## Overview

`@Api` marks the root of the client. It accepts an optional `UrlBuilder` value, which seeds the root `HttpContext`.

```swift
@Api(.host("api.example.com").adding(path: "v1"))
struct StoreAPI {}

let production = StoreAPI()
let staging = StoreAPI(url: .host("staging.example.com").adding(path: "v1"))
```

`@Path` creates a route node. If you omit the path string, Kiosk derives a kebab-case URL segment from the Swift type name.

```swift
@Api(.host("api.example.com"))
struct StoreAPI {
  @Path
  struct Users {
    @Path("recent-posts")
    struct RecentPosts {}
  }
}

let recentPosts = StoreAPI().users.recentPosts
```

Use `@Param` for dynamic path segments:

```swift
@Path
@Param("user-id", Int.self)
struct User {
  @Get
  struct Profile {
    typealias Response = Data
  }
}

let profile = try await api.users.user(userId: 42).profile()
```

## Generated Shape

Kiosk generates value-based route nodes. Each API, path, and endpoint value carries an `HttpContext`, and configuration changes return a new value with updated context.

```swift
let authenticated = api
  .header(.authorization, "Bearer token")
  .timeout(30)
```

This makes route trees cheap to pass around and easy to scope.

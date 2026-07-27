# Middleware

Use wrappers to inspect, mutate, retry, or sign requests.

## Overview

Middleware is implemented with `HttpWrapper`. A wrapper receives an `HttpRequest`, can inspect or mutate it, and then calls the next step in the chain.

```swift
struct AuthWrapper: HttpWrapper {
  let token: String

  func send(
    _ request: HttpRequest,
    next: @Sendable (HttpRequest) async throws -> HttpResponse<Data>
  ) async throws -> HttpResponse<Data> {
    var request = request
    request.headers.append(HttpHeader(.authorization, "Bearer \(token)").erased)
    return try await next(request)
  }
}
```

Register wrappers on any generated API, path, or endpoint value:

```swift
let api = StoreAPI()
  .register(.auth, AuthWrapper(token: token))
  .wrap(.auth)
```

`@Wrap` activates a registered wrapper for a scope. `@Unwrap` deactivates it for a nested scope.

```swift
@Api(.host("api.example.com"))
@Wrap(.auth)
struct StoreAPI {
  @Path
  @Unwrap(.auth)
  struct Public {}
}
```

## Guidance

Use middleware for cross-cutting behavior such as authorization, tracing, retries, logging, and request signing. Keep endpoint-specific request shape in macros and endpoint models.

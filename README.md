# Kiosk

Kiosk is a Swift-first way to declare discoverable REST clients with scoped request configuration.

Your client should look like the API it talks to: a route tree you can navigate in Swift, with endpoint-local request and response models, and inherited configuration for headers, content types, wire policy, and middleware.

## Documentation

- Full package documentation lives in `Sources/Kiosk/Kiosk.docc` and is configured for Swift Package Index hosting through `.spi.yml`.
- Agent-facing implementation guidance lives in `AGENTS.md`.

## Building Requests

Every HTTP request starts with four pieces: a method, a URL, headers, and optional content.

### `@Api`

`@Api` defines the root of a request tree. It is attached to a Swift struct because the generated client is value-based: every API, route, and endpoint value carries an `HttpContext`, and configuration changes return a new value with updated context.

The macro takes an optional `UrlBuilder` parameter. This seeds the default root URL used by `StoreAPI()`, and it uses the same API accepted by the generated `url:` initializer.

```swift
@Api(.host("api.example.com").adding(path: "v1"))
struct StoreAPI {}

let api = StoreAPI()
let staging = StoreAPI(url: .host("staging.example.com").adding(path: "v1"))
```

Under the hood, `@Api` generates context storage, initializers, context proxy methods, and stored child route values:

```swift
struct StoreAPI {
  var context: HttpContext

  init(context: HttpContext = HttpContext(url: .host("api.example.com").adding(path: "v1"))) {
    self.context = context
  }

  init(url: UrlBuilder) {
    self.init(context: HttpContext(url: url))
  }
}
```

`HttpContext` is the core request configuration object. It carries the current URL builder, headers, content-type defaults, accepted response type, request options, wire settings, error decoding, middleware registry, and `URLSession`.

### `@Path`

`@Path` creates a route node and appends a static path segment to the URL. Its optional string parameter is the exact segment to add. If no segment is provided, Kiosk derives one from the Swift type name by converting it to a URL path segment, so `Users` becomes `users` and `RecentPosts` becomes `recent-posts`.

Use `@Path` for stable route structure, not template placeholders. Dynamic URL segments belong to `@Param`.

```swift
@Api(.host("api.example.com"))
struct StoreAPI {
  @Path
  struct Users {
    @Path("recent-posts")
    struct RecentPosts {}
  }
}

let api = StoreAPI()
let posts = api.users.recentPosts
```

Route nodes inherit the API context and can later refine it with scoped configuration such as headers, content-type defaults, accepted response types, and middleware.

### `@Get`

`@Get` selects the GET method and turns a nested endpoint type into a callable request. The optional string parameter overrides the derived endpoint path segment.

```swift
@Get
struct Profile {
  typealias Response = Data
}

let profile = try await api.users.user(userId: 42).profile()
```

### `@Post`, `@Put`, And `@Patch`

`@Post`, `@Put`, and `@Patch` select body-friendly methods. A request body is discovered from a nested `Content` type, a `typealias Content`, or the single-value shorthand `@Content(Type.self)`.

```swift
@Post
@Header(.contentType, .json)
struct CreateUser {
  struct Content: Codable {
    let name: String
  }

  typealias Response = User
}

let created = try await api.users.createUser(.init(name: "Ada"))
```

### `@Delete`

`@Delete` selects the DELETE method. Like the other method macros, it accepts an optional string path override and uses the endpoint's `Response` contract for successful responses.

```swift
@Delete
struct DeleteUser {}
```

### `@Header`

`@Header` adds headers to requests. On an API or path, `@Header(key, value)` adds a default header to the inherited context. On an endpoint, `@Header(key)` declares a generated header argument using the key's value type.

Header keys are typed `HttpHeaderKey<Value>` values. The key defines the wire name and how values render; `HttpHeader<Value>` pairs a key with a value, and `AnyHttpHeader` is the erased string pair stored on requests.

`Content-Type` is a header in Kiosk. Use `@Header(.contentType, ...)` to choose the encoder for request `Content`.

```swift
@Api(.host("api.example.com"))
@Header(.accept, .json)
@Header(.contentType, .json)
struct StoreAPI {
  @Path
  @Header(.authorization, "Bearer user-token")
  struct Users {
    @Get
    @Header(.ifNoneMatch)
    struct Profile {
      typealias Response = Data
    }
  }
}

let api = StoreAPI()
let profile = try await api.users.profile(ifNoneMatch: "etag-1")
```

`@Header(key, default: value)` makes a generated endpoint argument optional at the callsite. Custom headers can use the explicit string form: `@Header("X-Trace-ID", String.self)`.

### `@Param`

`@Param` adds a dynamic path segment to a route or endpoint. Its first parameter is the URL parameter name; Kiosk derives the Swift argument label from it. Its second parameter is the Swift type accepted by the generated function.

The parameter value is appended to the URL path when the route value is called. Built-in path values include `String`, `Substring`, `Int`, `UUID`, and `Date`; custom values can participate by conforming to `UrlPathComponent`.

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

### `@Query`

`@Query` adds a query argument to an endpoint. The generated function appends the value to the URL as a key/value query item.

```swift
@Get
@Query("include-posts", Bool.self)
struct Profile {
  typealias Response = Data
}

let profile = try await api.users.user(userId: 42).profile(includePosts: true)
```

### `@Content`

`@Content(Type.self)` is shorthand for a single-value body when there is no useful nested struct to name. It does not set `Content-Type`; use `@Header(.contentType, ...)` for that.

```swift
@Post
@Header(.contentType, .binary)
@Content(Data.self)
struct Upload {
  typealias Response = Asset
}
```

Plain nested `Content` properties become JSON, form, or multipart fields depending on the active `Content-Type`. For multipart bodies, `@Part` marks a stored `Content` property as an explicit part marker.

```swift
@Post
@Header(.contentType, .multipart(boundary: "upload"))
struct Upload {
  struct Content {
    let title: String

    @Part
    let file: Data
  }

  typealias Response = Asset
}
```

### `@Status`

`@Status` registers a scoped error body for a non-success HTTP status. Put shared error models on the API or path where they should apply; endpoint structs still declare a single success `Response`.

```swift
@Api(.host("api.example.com"))
struct StoreAPI {
  @Status(.unauthorized)
  struct Unauthorized: Error, Codable {
    let message: String
  }
}
```

## Middleware

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

Wrappers are stored by `WrapperKey`. Kiosk includes common keys such as `.auth` and `.logging`, and custom keys can be declared in your app:

```swift
extension WrapperKey {
  static let idempotency = WrapperKey("idempotency")
}
```

Generated API, path, and endpoint values expose the same middleware methods as `HttpContext`:

- `register(key, wrapper)` stores a wrapper without activating it.
- `wrap(key, wrapper)` stores and activates a wrapper.
- `wrap(key)` activates a wrapper that was already registered higher in the tree.
- `wrap(key, wrapper, activate: false)` stores a wrapper for descendants without activating it at the current node.
- `unwrap(key)` deactivates one wrapper for that branch.
- `unwrapped()` deactivates all wrappers for that branch.

```swift
let api = StoreAPI("api.example.com")
  .register(.auth, AuthWrapper(token: token))
  .wrap(.logging, LoggingWrapper())

let authenticated = api.wrap(.auth)
let publicAPI = authenticated.unwrap(.auth)
let bareAPI = authenticated.unwrapped()
```

The same methods are available directly on `HttpContext` when you prefer to configure the root explicitly:

```swift
let api = StoreAPI(
  context: HttpContext(url: .host("api.example.com"))
    .register(.auth, AuthWrapper(token: token))
    .wrap(.auth)
)
```

`@Wrap` and `@Unwrap` apply the same activation rules in the route declaration itself. They are useful when authentication, logging, retries, or similar policies are part of the API shape:

```swift
@Api(.host("api.example.com"))
struct StoreAPI {
  @Path
  @Wrap(.auth)
  struct Account {
    @Get
    struct Profile {
      typealias Response = Data
    }
  }

  @Path
  @Unwrap(.auth)
  struct Public {
    @Get
    struct Status {
      typealias Response = Data
    }
  }
}
```

Wrappers run in active order and each wrapper decides whether to forward the request. That makes middleware suitable for auth headers, request IDs, retries, logging, response capture in tests, and endpoint-specific policy changes.

## Wire

Kiosk includes wire macros because REST clients usually need models that differ slightly from local Swift shape. `HttpContext` carries a plain `WireSpec`, and generated `@Wire` models read that spec from `JSONEncoder` and `JSONDecoder`.

Wire policy can be declared directly on an API, path, or endpoint:

```swift
@Api(.host("api.example.com"))
@Codec(.json)
@Rename(.snakeCase)
@Format(Date.self, .secondsSince1970)
@Format(Bool.self, .string)
@Default([String].self, [])
struct StoreAPI {}
```

`@Codec` chooses the document codec for the scope. JSON is the default and the only fully implemented codec for v0.1; YAML and XML are reserved in the type system.

`@Rename` chooses the field renaming policy for the scope. Available strategies include identity, camel case, Pascal case, snake case, screaming snake case, and kebab case.

`@Format(Type.self, value)` sets a scoped format for a Swift type. `@Format(value)` on a property wins over the scoped format.

```swift
@Wire
struct Session {
  @Format(.millisecondsSince1970)
  var expiresAt: Date

  var enabled: Bool
}
```

`@Default(Type.self, value)` sets a scoped decode fallback for a Swift type. `@Default(value)` on a property wins for that property.

```swift
@Wire
struct Page {
  @Default(1) var number: Int
  var items: [Item]
}
```

`@Field` overrides one property's wire key and takes priority over scoped renaming.

```swift
@Wire
struct Account {
  @Field("display_name") var name: String
}
```

The same policy can be configured at runtime through generated API, path, and endpoint proxy methods:

```swift
let api = StoreAPI("api.example.com")
  .codec(.json)
  .rename(.snakeCase)
  .format(Date.self, .iso8601)
  .wireDefault([String].self, [])
```

Form and multipart request content currently use content key metadata rather than the full `@Wire` encoder path. Use `@Key` for those field-name overrides until the content and wire naming APIs are unified.

## Ideas

Local model validation is intentionally out of the v0.1 package surface. Possible future validation macros include `@Validatable`, `@Required`, `@NonEmpty`, `@Range`, `@Pattern`, `@Past`, `@Future`, and `@Validate`, but Kiosk's current focus is API shape, request construction, middleware, and wire DTOs.

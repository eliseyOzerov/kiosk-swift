# Kiosk

Kiosk is a Swift-first way to declare discoverable REST clients with scoped request configuration.

Your client should look like the API it talks to: a route tree you can navigate in Swift, with endpoint-local request and response models, and inherited configuration for headers, content types, serialization, validation, and middleware.

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

`HttpContext` is the core request configuration object. It carries the current URL builder, headers, content-type defaults, accepted response type, request options, serialization settings, error decoding, middleware registry, and `URLSession`.

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

## Callsites

Kiosk is designed around callsites that reveal the API shape:

```swift
let api = StoreAPI("api.example.com")

let search = try await api.users.search(q: "ada")
let profile = try await api.users.user(userId: 42).profile()
let session = try await api.sessions.login(email: email, password: password)
```

Instead of spreading paths and request construction across the app:

```swift
try await client.get("/users/\(id)/posts", query: ["q": query])
```

Kiosk keeps the path, method, parameters, body, response, and request configuration together in Swift source.

## Implementing A Client

An API starts with an `@Api` or `@Path` root that stores an `HttpContext`. Nested `@Path` structs become route nodes, and endpoint structs use HTTP method macros such as `@Get` and `@Post`.

```swift
import Kiosk

@Api(.host("api.example.com"))
@Header(.contentType, .json)
@Header(.accept, .json)
struct StoreAPI {
  @Path
  struct Users {
    @Get
    @Query("q", String.self)
    struct Search {
      @Serializable
      struct Response {
        var users: [User]
      }
    }

    @Path
    @Param("user-id", Int.self)
    struct User {
      @Get
      struct Profile {
        @Serializable
        struct Response {
          var id: Int
          var name: String
        }
      }
    }
  }

  @Path
  struct Sessions {
    @Post
    @Header(.contentType, .form)
    struct Login {
      struct Content {
        let email: String
        let password: String
      }

      typealias Response = Data
    }
  }
}
```

The generated client keeps a copy of `HttpContext` at every node. Route nodes refine the context by appending path components or changing configuration. Endpoint calls turn that context into an `HttpRequest`, run wrappers, send a `URLRequest` through `URLSession`, and decode the response into the endpoint's declared result shape.

## Request Anatomy

Kiosk can express the main parts of a REST request:

- Base URL through `@Api`, generated initializers, or `HttpContext`.
- `URLSession` through `HttpContext`.
- Static path segments through nested `@Path` types.
- Dynamic path segments through `@Param`.
- HTTP method through `@Get`, `@Post`, `@Put`, `@Patch`, or `@Delete`.
- Query values through `@Query` attributes or a nested `@Query` type.
- Headers through `@Header` attributes or a nested `Headers` type.
- Request body through nested `Content`, `typealias Content`, or `@Content(Type.self)`.
- Content encoding through `@Header(.contentType, ...)`; accepted response type through `@Header(.accept, ...)`.
- Shared non-success error decoding through scoped `@Status` models.
- Middleware through `HttpWrapper`, `.wrap(...)`, `@Wrap`, and `@Unwrap`.

## API Configuration

`@Api` can seed the root URL for the generated default initializer using the same `UrlBuilder` API accepted by the generated `url:` initializer:

```swift
@Api(.host("api.example.com").scheme(.https).adding(path: "v1"))
struct StoreAPI {}

let api = StoreAPI()
```

You can still override that default at construction time:

```swift
let api = StoreAPI("api.example.com")
let staging = StoreAPI(url: .host("staging.example.com").scheme(.http).adding(path: "v1"))
```

`HttpContext` is the request configuration driver. It stores the base URL, session, headers, content-type defaults, accepted response type, request options, serialization settings, error decoding, and wrapper registry.

Generated API, route, and endpoint values proxy the common `HttpContext` configuration methods, so most callsites do not need to touch `context` directly:

```swift
let api = StoreAPI("api.example.com")
  .adding(header: HttpHeader(.accept, .json))
  .wrap(.auth, AuthWrapper(token: token))

let search = api.users.search
  .adding(query: UrlQueryItem(name: "locale", value: "en"))
```

For custom sessions, wrappers, error decoding, or request options, construct an `HttpContext` explicitly:

```swift
let api = StoreAPI(
  context: HttpContext(session: session, url: .host("api.example.com"))
    .wrap(.auth, AuthWrapper(token: token))
)
```

Configuration flows through the tree. Defaults can live at the root, and routes or endpoints can override them:

```swift
@Api
@Header(.contentType, .json)
@Header(.accept, .json)
struct API {
  @Path
  struct Sessions {
    @Post
    @Header(.contentType, .form)
    struct Login {
      struct Content {
        let email: String
        let password: String
      }

      typealias Response = Data
    }
  }
}
```

Here the API defaults to JSON content, while `Sessions.Login` sends form-encoded content.

## Paths And Parameters

Use `@Path` to create route nodes. If no explicit segment is provided, Kiosk derives the segment from the Swift type name.

```swift
@Path
struct Users {
  @Path
  @Param("user-id", Int.self)
  struct User {
    @Path
    struct Posts {}
  }
}
```

The generated callsite follows the route:

```swift
api.users.user(userId: 42).posts
```

Explicit path names are available when the remote API does not match Swift naming:

```swift
@Path("v1")
struct V1 {}
```

## Requests And Data Models

Endpoint structs use method macros to declare how a request is sent:

```swift
@Get
@Query("q", String.self)
@Header("X-Trace-ID", String.self, default: "trace")
struct Search {
  @Serializable
  struct Response {
    var items: [String]
  }
}
```

For request bodies, declare a nested `Content` type near the endpoint:

```swift
@Post
@Header(.contentType, .json)
struct CreatePost {
  struct Content: Codable {
    var title: String
    var body: String
  }

  struct Response: Codable {
    var id: UUID
  }
}
```

Larger payloads can be named explicitly:

```swift
@Post
struct ReplacePost {
  @Serializable
  struct Content {
    var title: String
    var body: String
  }

  typealias Response = Data
}
```

Shared non-success responses are registered as scoped errors:

```swift
@Api(.host("api.example.com"))
struct StoreAPI {
  @Status(.badRequest)
  struct ValidationError: Error, Codable {
    var message: String
  }
}
```

## Serialization

Kiosk includes serialization macros because REST clients usually need local wire models.

```swift
@Serializable
struct Account {
  @Field("display_name") var name: String
  @Format(.string) var enabled: Bool
  @Default(0) var loginCount: Int
}
```

`@Serializable` generates `Codable` behavior using `SerializationContext`. `@Field` changes a wire key, `@Format` customizes supported value formats, and `@Default` provides a decode fallback.

## Client-Side Validation

Validation is local model validation. It does not replace server validation, but it is useful before sending request bodies or accepting user-entered values.

```swift
@Validatable
struct Signup {
  @Required var email: String?
  @Pattern(.email) var normalizedEmail: String?
  @NonEmpty var password: String
}
```

Available validation rules include required values, non-empty strings and collections, ranges, regular-expression patterns, past/future dates, and custom validators.

## Under The Hood

Kiosk's macros generate ordinary Swift around a small runtime:

- Route macros generate context storage and child route accessors.
- Parameter macros generate route functions that append dynamic path components.
- Endpoint macros generate request `Content`, `Query`, `Headers`, and `Result` helpers.
- Endpoint calls build an `HttpRequest`.
- Wrappers run in active order and can mutate the request.
- Transport converts the request to `URLRequest` and uses `URLSession`.
- Response data is decoded into declared status cases, or throws on unexpected status.

## Roadmap

- First-class prepared request objects that can be built, inspected, updated, and sent later.
- Function-style endpoint macros as shorthand over the same endpoint model.
- DocC reference documentation.
- Macro expansion tests for diagnostics and generated source shape.
- More examples for auth, pagination, uploads, retries, idempotency keys, and status enums.
- A public decision on WebSocket support.
- Serialization cleanup: keep `@Key` temporarily, then decide whether `@Field` should cover query and content field names too.

## Installation

After the first release:

```swift
dependencies: [
  .package(url: "https://github.com/ozerov-studio/kiosk-swift.git", from: "0.1.0")
]
```

```swift
.target(
  name: "YourTarget",
  dependencies: [
    .product(name: "Kiosk", package: "kiosk-swift")
  ]
)
```

## Status

Kiosk is being prepared for an initial `0.1.0` release. The REST client surface, macro behavior, and public naming are experimental until a `1.0.0` release.

REST is the first-class focus. WebSocket runtime types exist, but they are not part of the documented v0.1 contract yet.

## License

Kiosk is available under the MIT license.

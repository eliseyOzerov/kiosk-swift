# Kiosk

Kiosk is a Swift-first way to declare discoverable REST clients with scoped request configuration.

Your client should look like the API it talks to: a route tree you can navigate in Swift, with endpoint-local request and response models, and inherited configuration for headers, content types, serialization, validation, and middleware.

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

@Api
@Content(.json)
@Accept(.json)
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
    @Content(.form)
    @Field("email", String.self)
    @Field("password", String.self)
    struct Login {
      typealias Response = Data
    }
  }
}
```

The generated client keeps a copy of `HttpContext` at every node. Route nodes refine the context by appending path components or changing configuration. Endpoint calls turn that context into an `HttpRequest`, run wrappers, send a `URLRequest` through `URLSession`, and decode the response into the endpoint's declared result shape.

## Request Anatomy

Kiosk can express the main parts of a REST request:

- Base URL and `URLSession` through `HttpContext`.
- Static path segments through nested `@Path` types.
- Dynamic path segments through `@Param`.
- HTTP method through `@Get`, `@Post`, `@Put`, `@Patch`, or `@Delete`.
- Query values through `@Query` attributes or a nested `@Query` type.
- Headers through `@Header` attributes or a nested `Headers` type.
- Request body through `@Content`, `@Field`, `@Part`, nested `Content`, or `typealias Content`.
- Content negotiation through `@Content` and `@Accept`.
- Response status mapping through nested `Response` types and `@Response`.
- Middleware through `HttpWrapper`, `.wrap(...)`, `@Wrap`, and `@Unwrap`.

## API Configuration

`HttpContext` is the request configuration driver. It stores the base URL, session, headers, content defaults, accepted response type, request options, serialization settings, error decoding, and wrapper registry.

```swift
let api = StoreAPI("api.example.com")
let staging = StoreAPI(url: .host("staging.example.com").scheme(.http))
```

Generated API, route, and endpoint values proxy the common `HttpContext` configuration methods, so most callsites do not need to touch `context` directly:

```swift
let api = StoreAPI("api.example.com")
  .adding(header: .accept(.json))
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
@Content(.json)
@Accept(.json)
struct API {
  @Path
  struct Sessions {
    @Post
    @Content(.form)
    @Field("email", String.self)
    @Field("password", String.self)
    struct Login {
      typealias Response = Data
    }
  }
}
```

Here the API defaults to JSON, while `Sessions.Login` sends form-encoded content.

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

For request bodies, small payloads can be generated from fields:

```swift
@Post
@Field("title", String.self)
@Field("body", String.self)
struct CreatePost {
  @Response(.created)
  struct Response {
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

Status-specific responses produce explicit result cases:

```swift
@Post
struct CreateUser {
  @Response(.created)
  struct Response {
    var id: UUID
  }

  @Response(.badRequest)
  struct ValidationError {
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

## Middleware

Middleware is implemented with `HttpWrapper`. Wrappers receive an `HttpRequest`, can inspect or mutate it, and then call the next step in the chain.

```swift
struct AuthWrapper: HttpWrapper {
  let token: String

  func send(
    _ request: HttpRequest,
    next: @Sendable (HttpRequest) async throws -> HttpResponse<Data>
  ) async throws -> HttpResponse<Data> {
    var request = request
    request.headers.append(HttpHeader(name: .authorization, value: "Bearer \(token)"))
    return try await next(request)
  }
}
```

Register and activate wrappers through context:

```swift
let api = StoreAPI("api.example.com")
  .wrap(.auth, AuthWrapper(token: token))
```

Routes can activate or deactivate registered wrappers:

```swift
@Path
@Wrap(.auth)
struct Private {}

@Path
@Unwrap(.auth)
struct Public {}
```

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
- A pre-release decision on whether inherited dictionary/value helper macros stay public, become internal, or move to another package.

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

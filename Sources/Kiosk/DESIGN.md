# Kiosk Design And Coverage

Kiosk's premise is that a REST client should be declared in the same shape as the API it calls. Instead of hiding paths in flat methods or generated artifacts, Kiosk uses nested Swift types to make routes, endpoint contracts, request configuration, and response handling discoverable at the callsite.

The core runtime type is `HttpContext`. It carries the base URL, session, headers, content defaults, accepted response type, serialization settings, error decoding, request options, and wrappers. Route macros copy and refine that context as the call path moves from the root to a specific endpoint.

```swift
@Api(.host("api.example.com"))
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
  }
}
```

At the callsite, the API surface follows the route tree:

```swift
let api = StoreAPI()
let response = try await api.users.search(q: "ada")
```

## Design Claims

- API declarations are Swift source, not generated files.
- Nested routes make the client surface discoverable through dot access.
- `@Api` can seed the default root URL with `UrlBuilder`, while `HttpContext` drives request construction and carries inherited configuration.
- Endpoint-local `Query`, `Headers`, `Content`, and `Response` types keep contracts near their endpoint.
- Macros generate ordinary request-building code that ends in `URLRequest`.
- Serialization and validation macros can be reused for local models used by requests and responses.

## Runtime Areas

- URL construction: `UrlBuilder`, `UrlScheme`, `UrlPort`, `UrlPathComponent`, `UrlQueryItem`, `UrlQueryValue`.
- HTTP modeling: `HTTPMethod`, `HTTPHeaderFieldName`, `HttpHeader`, `HTTPContentType`, `HTTPStatusCode`, `HttpRequest`, `HttpResponse`.
- Context and wrappers: `HttpContext`, `RequestContext`, `WrapperKey`, `WrapperRegistry`, `HttpWrapper`, `HttpOptions`.
- Encoding and decoding: `SerializationContext`, `Serializable`, `UrlQueryEncoder`, `HttpHeaderEncoder`, `HTTPContentEncoder`.
- Local model support: `Dictable`, `Valuable`, `Validatable`, `ValidationContext`.
- WebSocket context exists as experimental runtime surface and is not part of the v0.1 README promise.

## Test Coverage

- URL, header, content type, and status helpers are covered in `KioskTests`.
- Nested path generation, parameterized routes, method macros, query, headers, request content, response decoding, and declared status results are covered in `KioskTests`.
- Accept/content inheritance, wrapper scoping, custom method paths, manual headers/content, unexpected status errors, and wrapper ordering are covered in `KioskProofTests`.
- Single-import dictionary/value, serialization, and validation macro behavior is covered in `KioskLocalModelTests`.

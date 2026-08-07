# Headers

Set default headers on scopes and declare endpoint header arguments.

## Overview

`@Header` works on APIs, paths, and endpoints. A default header writes into inherited context, while a typed header declaration generates a callsite argument.

```swift
@Api(.host("api.example.com"))
@Header(.accept, .json)
@Header(.contentType, .json)
struct StoreAPI {
  @Path
  @Header(.authorization, .bearer("token"))
  struct Users {
    @Get
    @Header(.ifNoneMatch)
    struct Profile {
      typealias Response = Data
    }
  }
}

let profile = try await StoreAPI().users.profile(ifNoneMatch: "etag-1")
```

## Typed Header Keys

Header keys are `HttpHeaderKey<Value>` values. The key stores the wire name and value encoder. `HttpHeader<Value>` pairs a key with a value, and `AnyHttpHeader` stores the erased string form used on requests.

Use built-in keys when possible:

```swift
@Header(.accept, .json)
@Header(.contentType, .json)
@Header(.authorization, .bearer("token"))
```

Use custom string headers when the package does not provide a typed key:

```swift
@Header("X-Trace-ID", String.self)
struct ShowInvoice {
  typealias Response = Invoice
}
```

## Content Type

`Content-Type` is just a header in Kiosk. Use `@Header(.contentType, ...)` to pick how endpoint content is encoded.

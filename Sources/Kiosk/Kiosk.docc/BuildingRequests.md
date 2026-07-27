# Building Requests

Build requests from a method, URL, headers, and optional content.

## Overview

Kiosk request declarations start with an `@Api` root. Route nodes and endpoints inherit an `HttpContext`, so configuration can be set once and refined where the API shape needs it.

```swift
@Api(.host("api.example.com").adding(path: "v1"))
@Header(.accept, .json)
@Header(.contentType, .json)
struct StoreAPI {
  @Path
  struct Users {
    @Get
    @Query("include-posts", Bool.self)
    struct Index {
      typealias Response = [User]
    }

    @Post
    struct Create {
      struct Content: Codable {
        let name: String
      }

      typealias Response = User
    }
  }
}
```

Calling generated endpoints runs the configured request through the active middleware chain and decodes the declared response:

```swift
let api = StoreAPI()

let users = try await api.users.index(includePosts: true)
let created = try await api.users.create(.init(name: "Ada"))
```

## Execution

Generated endpoints are callable values. Calling an endpoint builds a runtime `HttpRequest`, runs it through active middleware, performs the transport, validates the status, and returns the declared success `Response`.

Use middleware when callers need to inspect, mutate, sign, retry, or record requests before transport. A separately runnable endpoint request object is not part of the v0.1 public surface.

## Request Pieces

- URL shape comes from `@Api`, `@Path`, `@Param`, method path overrides, and `@Query`.
- Method comes from `@Get`, `@Post`, `@Put`, `@Patch`, or `@Delete`.
- Headers come from `@Header` macros or context proxy methods.
- Content comes from nested `Content`, `typealias Content`, or `@Content(Type.self)`.

See <doc:RouteTrees>, <doc:RequestParameters>, and <doc:Headers> for the details.

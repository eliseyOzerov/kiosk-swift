# ``Kiosk``

Declare discoverable REST clients with Swift route trees and scoped request configuration.

## Overview

Kiosk lets an API client look like the service it talks to. You define an `@Api` root, nest `@Path` route nodes, and place method endpoints where requests belong. The generated Swift surface stays discoverable through dot navigation while `HttpContext` carries inherited request configuration.

```swift
@Api(.host("api.example.com").adding(path: "v1"))
@Header(.accept, .json)
@Header(.contentType, .json)
struct StoreAPI {
  @Path
  struct Users {
    @Path
    @Param("user-id", Int.self)
    struct User {
      @Get
      struct Profile {
        typealias Response = ProfileResponse
      }
    }
  }
}

let api = StoreAPI()
let profile = try await api.users.user(userId: 42).profile()
```

Kiosk focuses on REST-shaped clients, request construction, middleware, and wire DTOs. WebSocket support exists in the package but is experimental and is not part of the v0.1 documentation claims.

## Topics

### Requests

- <doc:BuildingRequests>
- <doc:RouteTrees>
- <doc:RequestParameters>
- <doc:Headers>
- <doc:StatusResponses>

### Configuration

- <doc:Middleware>
- <doc:WireModels>

### Development

- <doc:Testing>

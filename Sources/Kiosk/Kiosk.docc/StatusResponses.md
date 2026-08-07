# Status Responses

Declare success responses on endpoints and scoped error bodies with `@Status`.

## Success Responses

Each endpoint declares one success response model with `typealias Response` or a nested `Response` type.

```swift
@Get
struct Profile {
  typealias Response = UserProfile
}
```

## Error Bodies

Use `@Status` for non-success HTTP status models. Put shared error models on the API or path where they apply.

```swift
@Api(.host("api.example.com"))
struct StoreAPI {
  @Status(.unauthorized)
  struct Unauthorized: Codable {
    let message: String
  }

  @Path
  struct Users {
    @Status(.notFound)
    struct NotFound: Codable {
      let message: String
    }
  }
}
```

Kiosk throws typed HTTP errors for registered error bodies:

```swift
do {
  _ = try await api.users.profile()
} catch let error as HttpError<StoreAPI.Users.NotFound> {
  print(error.code)
  print(error.message)
  print(error.payload)
}
```

You can also throw status-only errors manually:

```swift
throw HttpError(.unauthorized)
```

`HttpError` contains the HTTP status code, an optional `message` decoded from the error body, and the payload decoded from the nearest matching `@Status` struct in the route tree. If a response status has no registered error body, Kiosk throws an unexpected-status error with the raw response data.

## Scope

Status models inherit through the route tree. Prefer API-level status models for global errors such as authorization failures, and path-level status models for domain-specific errors.

# Request Parameters

Declare path parameters, query arguments, and request content beside the endpoint that uses them.

## Path Parameters

`@Param` appends a dynamic URL path segment. The first argument is the URL parameter name, and the second is the Swift type accepted by the generated function.

```swift
@Path
@Param("post-id", UUID.self)
struct Post {
  @Get
  struct Detail {
    typealias Response = PostResponse
  }
}

let post = try await api.posts.post(postId: id).detail()
```

## Query Arguments

`@Query` appends a query item to the endpoint URL.

```swift
@Get
@Query("page", Int.self)
@Query("include-archived", Bool.self)
struct Index {
  typealias Response = [Order]
}

let orders = try await api.orders.index(page: 1, includeArchived: false)
```

For grouped query models, use a nested query model with `@Query`.

```swift
@Get
struct Search {
  @Query
  struct Query: Codable {
    let q: String
    let limit: Int
  }

  typealias Response = [Product]
}
```

## Content

Body-friendly methods discover request content from a nested `Content` type, a `typealias Content`, or the single-value shorthand `@Content(Type.self)`.

```swift
@Post
struct CreateUser {
  struct Content: Codable {
    let name: String
    let email: String
  }

  typealias Response = User
}
```

`@Content(Type.self)` is useful for single-value uploads:

```swift
@Post
@Header(.contentType, .binary)
@Content(Data.self)
struct UploadAvatar {
  typealias Response = Asset
}
```

For multipart content, mark explicit parts with `@Part`.

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

import Kiosk
import Foundation
import XCTest

final class KioskTests: XCTestCase {
  func testUrlBuilderBuildsStructuredURL() throws {
    let url = try UrlBuilder
      .host("example.com")
      .scheme(.https)
      .port(.alternateHTTPS)
      .adding(path: "v1")
      .adding(path: 42)
      .adding(query: UrlQueryItem(name: "search", value: "forge kit"))
      .build()

    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    XCTAssertEqual(components.scheme, "https")
    XCTAssertEqual(components.host, "example.com")
    XCTAssertEqual(components.port, 8443)
    XCTAssertEqual(components.path, "/v1/42")
    XCTAssertEqual(components.queryItems, [URLQueryItem(name: "search", value: "forge kit")])
  }

  func testHTTPHeaderNamesCompareCaseInsensitively() {
    let contentType = HTTPHeaderFieldName("Content-Type")
    let lowercase = HTTPHeaderFieldName("content-type")

    XCTAssertEqual(contentType, lowercase)
    XCTAssertEqual(Set([contentType, lowercase]).count, 1)
  }

  func testHTTPContentTypesUseShortNames() {
    XCTAssertEqual(HTTPContentType.any.rawValue, "*/*")
    XCTAssertEqual(HTTPContentType.json.rawValue, "application/json")
    XCTAssertEqual(HTTPContentType.problem.rawValue, "application/problem+json")
    XCTAssertEqual(HTTPContentType.form.rawValue, "application/x-www-form-urlencoded")
    XCTAssertEqual(HTTPContentType.binary.rawValue, "application/octet-stream")
    XCTAssertEqual(HTTPContentType.html.rawValue, "text/html")
    XCTAssertEqual(HTTPContentType.jpeg.rawValue, "image/jpeg")
    XCTAssertEqual(HTTPContentType.png.rawValue, "image/png")
    XCTAssertEqual(HTTPContentType.text.rawValue, "text/plain")
    XCTAssertEqual(HTTPContentType.utf8.rawValue, "text/plain; charset=utf-8")
    XCTAssertEqual(HTTPContentType.multipart(boundary: "forge").rawValue, "multipart/form-data; boundary=forge")
    XCTAssertEqual(HttpHeader.contentType(.json), HttpHeader(name: .contentType, value: "application/json"))
    XCTAssertEqual(HttpHeader.accept(.json), HttpHeader(name: .accept, value: "application/json"))
  }

  func testHTTPStatusCodeClassAndReasonPhrase() {
    XCTAssertEqual(HTTPStatusCode.ok.statusClass, .success)
    XCTAssertTrue(HTTPStatusCode.created.isSuccess)
    XCTAssertEqual(HTTPStatusCode.notFound.statusClass, .clientError)
    XCTAssertEqual(HTTPStatusCode.serviceUnavailable.reasonPhrase, "Service Unavailable")
  }

  func testHttpContextCanConfigureWrappersWithoutExternalProducts() {
    let context = HttpContext(url: .host("example.com"))
      .wrap(.logging, PassthroughWrapper())
      .unwrap(.logging)

    XCTAssertEqual(context.wrappers.activeKeys, [])
  }

  func testApiRootConvenienceInitializersBuildContext() {
    let shorthand = StoreAPI("example.com")
    XCTAssertEqual(shorthand.context.url.host, "example.com")
    XCTAssertEqual(shorthand.context.url.scheme, .https)
    XCTAssertEqual(shorthand.users.context.url.path.map(\.urlPathComponent), ["users"])

    let labeled = StoreAPI(host: "api.example.com")
    XCTAssertEqual(labeled.context.url.host, "api.example.com")

    let versioned = StoreAPI(url: .host("example.com").scheme(.http).adding(path: "v1"))
    XCTAssertEqual(versioned.context.url.scheme, .http)
    XCTAssertEqual(versioned.users.context.url.path.map(\.urlPathComponent), ["v1", "users"])
  }

  func testApiProxyMethodsRebuildChildContexts() {
    let header = HttpHeader(name: "X-Client", value: "kiosk")
    let api = StoreAPI("example.com")
      .scheme(.http)
      .adding(path: "v1")
      .adding(header: header)

    XCTAssertEqual(api.context.url.scheme, .http)
    XCTAssertEqual(api.users.context.url.path.map(\.urlPathComponent), ["v1", "users"])
    XCTAssertEqual(api.users.context.headers, [header])
  }

  func testApiProxyMethodsCanRegisterMiddleware() async throws {
    let recorder = RequestRecorder()
    let api = StoreAPI("example.com")
      .wrap(.capture, RecordingWrapper(recorder: recorder))

    _ = try await api.users.search(q: "kiosk", page: 1)
    let lastRequest = await recorder.last()
    let recordedRequest = try XCTUnwrap(lastRequest)

    XCTAssertEqual(recordedRequest.url.host, "example.com")
    XCTAssertEqual(recordedRequest.url.path.map(\.urlPathComponent), ["users", "search"])
  }

  func testRouteAndEndpointProxyMethodsCanUpdateRequests() async throws {
    let recorder = RequestRecorder()
    let endpoint = StoreAPI("example.com")
      .users
      .adding(header: HttpHeader(name: "X-Route", value: "users"))
      .search
      .adding(query: UrlQueryItem(name: "locale", value: "en"))
      .wrap(.capture, RecordingWrapper(recorder: recorder))

    _ = try await endpoint(q: "kiosk", page: 1)
    let lastRequest = await recorder.last()
    let recordedRequest = try XCTUnwrap(lastRequest)

    XCTAssertEqual(recordedRequest.headers, [HttpHeader(name: "X-Route", value: "users")])
    XCTAssertEqual(recordedRequest.url.query, [
      UrlQueryItem(name: "locale", value: "en"),
      UrlQueryItem(name: "q", value: "kiosk"),
      UrlQueryItem(name: "page", value: "1"),
    ])
  }

  func testPathMacrosBuildNestedContextWithKioskImport() {
    let projects = TenantAPI(context: HttpContext(url: .host("example.com")))
      .tenants
      .tenant(tenantId: 7)
      .projects

    XCTAssertEqual(projects.context.url.path.map { $0.urlPathComponent }, ["tenants", "7", "projects"])
  }

  func testGetMacroBuildsRequestWithQueryParameters() async throws {
    let recorder = RequestRecorder()
    let api = StoreAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: recorder))
    )

    let result = try await api.users.search(q: "forge", page: 2)
    let recordedRequest = await recorder.last()
    let request = try XCTUnwrap(recordedRequest)
    let data: Data
    switch result {
    case .ok(let body):
      data = body
    }

    XCTAssertEqual(String(data: data, encoding: .utf8), "ok")
    XCTAssertEqual(request.method, .get)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["users", "search"])
    XCTAssertEqual(Set(request.url.query), Set([
      UrlQueryItem(name: "q", value: "forge"),
      UrlQueryItem(name: "page", value: "2"),
    ]))
  }

  func testPostMacroBuildsRequestContent() async throws {
    let recorder = RequestRecorder()
    let api = StoreAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: recorder))
    )

    _ = try await api.users.create(name: "Ada")
    let recordedRequest = await recorder.last()
    let request = try XCTUnwrap(recordedRequest)
    let body = try XCTUnwrap(request.body)
    let decoded = try JSONDecoder().decode(StoreAPI.Users.Create.Content.self, from: body)

    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["users", "create"])
    XCTAssertEqual(request.headers.last { $0.name == .contentType }, .contentType(.json))
    XCTAssertEqual(decoded.name, "Ada")
    XCTAssertNil(decoded.displayName)
  }

  func testEndpointStructMacrosBuildComprehensiveAPI() async throws {
    let recorder = RequestRecorder()
    let responseBody = try JSONEncoder().encode(ComprehensiveAPI.Posts.MutationResponse(ok: true))
    let api = ComprehensiveAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: recorder, body: responseBody))
    )
    let date = Date(timeIntervalSince1970: 0)
    let postDate = date
    let slug = "launch"
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    _ = try await api.posts.post(date: date, slug: slug).get(ifNoneMatch: "etag-1")
    var recordedRequest = await recorder.last()
    var request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .get)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "1970-01-01T00:00:00Z", "launch"])
    XCTAssertEqual(request.headers, [
      .init(name: .ifNoneMatch, value: "etag-1"),
    ])

    _ = try await api.posts.post(date: date, slug: slug).replace(
      .init(title: "Updated")
    )
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .put)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "1970-01-01T00:00:00Z", "launch", "replace"])

    _ = try await api.posts.post(date: date, slug: slug).update(
      .init(title: "Patch")
    )
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .patch)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "1970-01-01T00:00:00Z", "launch", "update"])

    _ = try await api.posts.post(date: date, slug: slug).delete()
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .delete)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "1970-01-01T00:00:00Z", "launch"])

    _ = try await api.posts.publish(postDate: postDate, slug: slug)(
      title: "New",
      notify: true
    )
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "publish", "1970-01-01T00:00:00Z", "launch"])
    XCTAssertEqual(request.url.query, [
      UrlQueryItem(name: "notify", value: "true"),
    ])
    XCTAssertEqual(request.headers.last { $0.name == .contentType }, .contentType(.json))

    let searchBody = try JSONEncoder().encode(ComprehensiveAPI.Posts.Search.Response(items: ["a"]))
    let searchAPI = ComprehensiveAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: recorder, body: searchBody))
    )

    _ = try await searchAPI.posts.search(
      query: .init(term: "forge", page: nil, createdAfter: date)
    )
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .get)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "search"])
    XCTAssertEqual(Set(request.url.query), Set([
      UrlQueryItem(name: "created_after", value: "1970-01-01T00:00:00Z"),
      UrlQueryItem(name: "term", value: "forge"),
    ]))
    XCTAssertEqual(request.headers, [
      .init(name: "X-Trace-ID", value: "trace"),
    ])

    _ = try await api.posts.byAuthor(query: .init(authorID: id, includeDrafts: false))
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .get)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "by-author"])
    XCTAssertEqual(Set(request.url.query), Set([
      UrlQueryItem(name: "author_id", value: id.uuidString),
      UrlQueryItem(name: "includeDrafts", value: "false"),
    ]))

    _ = try await api.posts.externalSearch(query: .init(term: "typed", limit: 10))
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .get)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "external-search"])
    XCTAssertEqual(Set(request.url.query), Set([
      UrlQueryItem(name: "term", value: "typed"),
      UrlQueryItem(name: "limit", value: "10"),
    ]))

    _ = try await api.posts.review(.init(title: "Alias"))
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    let body = try XCTUnwrap(request.body)
    let decoded = try JSONDecoder().decode(PostReviewBody.self, from: body)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "review"])
    XCTAssertEqual(decoded.title, "Alias")

    _ = try await api.posts.login(emailAddress: "a@b.com", password: "secret")
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    let formBody = try XCTUnwrap(request.body)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "login"])
    XCTAssertEqual(request.headers.last { $0.name == .contentType }, .contentType(.form))
    XCTAssertEqual(String(data: formBody, encoding: .utf8), "email-address=a%40b.com&password=secret")

    let data = Data([0, 1, 2])
    _ = try await api.posts.upload(data)
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "upload"])
    XCTAssertEqual(request.headers.last { $0.name == .contentType }, .contentType(.binary))
    XCTAssertEqual(request.body, data)

    _ = try await api.posts.attach(title: "Attachment", file: Data("bytes".utf8))
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    let multipartBody = try XCTUnwrap(request.body)
    let multipart = try XCTUnwrap(String(data: multipartBody, encoding: .utf8))
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "attach"])
    XCTAssertEqual(request.headers.last { $0.name == .contentType }, .contentType(.multipart(boundary: "fixture")))
    XCTAssertTrue(multipart.contains("--fixture\r\nContent-Disposition: form-data; name=\"title\"\r\n\r\nAttachment\r\n"))
    XCTAssertTrue(multipart.contains("--fixture\r\nContent-Disposition: form-data; name=\"file\"\r\nContent-Type: application/octet-stream\r\n\r\nbytes\r\n"))
    XCTAssertTrue(multipart.hasSuffix("--fixture--\r\n"))

    _ = try await api.posts.comment("hello")
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "comment"])
    XCTAssertEqual(request.headers.last { $0.name == .contentType }, .contentType(.text))
    XCTAssertEqual(request.body, Data("hello".utf8))
  }

  func testEndpointStructMacrosReturnDeclaredResults() async throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let createdBody = try JSONEncoder().encode(ContractAPI.Users.Create.Response(id: id))
    let createdAPI = ContractAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: RequestRecorder(), body: createdBody, status: .created))
    )

    let created = try await createdAPI.users.create(name: "Ada")
    switch created {
    case .created(let response):
      XCTAssertEqual(response.id, id)
    case .badRequest:
      XCTFail("Expected created response")
    }

    let errorBody = try JSONEncoder().encode(
      ContractAPI.Users.Create.ValidationError(message: "Name is required")
    )
    let failedAPI = ContractAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: RequestRecorder(), body: errorBody, status: .badRequest))
    )

    let failed = try await failedAPI.users.create(name: "")
    switch failed {
    case .created:
      XCTFail("Expected validation error response")
    case .badRequest(let error):
      XCTAssertEqual(error.message, "Name is required")
    }

    let profileBody = try JSONEncoder().encode(ContractAPI.Users.Profile.Response(name: "Ada"))
    let profileAPI = ContractAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: RequestRecorder(), body: profileBody))
    )

    let profile = try await profileAPI.users.profile()
    switch profile {
    case .ok(let response):
      XCTAssertEqual(response.name, "Ada")
    case .notFound:
      XCTFail("Expected profile response")
    }

    let deletedAPI = ContractAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: RequestRecorder(), body: Data(), status: .noContent))
    )

    let deleted = try await deletedAPI.users.delete()
    switch deleted {
    case .noContent:
      break
    }
  }
}

@Path
private struct TenantAPI {
  @Path
  struct Tenants {
    @Path
    @Param("tenant-id", Int.self)
    struct Tenant {
      @Path
      struct Projects {}
    }
  }
}

@Path
private struct StoreAPI {
  @Path
  struct Users {
    @Get
    @Query("q", String.self)
    @Query("page", Int.self)
    @Query("tag", Optional<String>.self)
    struct Search {
      typealias Response = Data
    }

    @Post
    @Field("name", String.self)
    @Field("display-name", Optional<String>.self)
    struct Create {
      typealias Response = Data
    }
  }
}

@Content(.json)
@Accept(.json)
@Path
private struct ComprehensiveAPI {
  @Path
  struct Posts {
    @Serializable
    struct MutationResponse: Equatable {
      let ok: Bool
    }

    @Path
    @Param("date", Date.self)
    @Param("slug", String.self)
    struct Post {
      typealias Response = Posts.MutationResponse

      @Get
      @Header(.ifNoneMatch, String.self)
      struct Get {}

      @Put
      struct Replace {
        struct Content: Equatable, Codable {
          let title: String
        }

        typealias Response = Posts.MutationResponse
      }

      @Patch
      struct Update {
        struct Content: Equatable, Codable {
          let title: String
        }

        typealias Response = Posts.MutationResponse
      }

      @Delete
      struct Delete {}
    }

    @Post
    @Param("post-date", Date.self)
    @Param("slug", String.self)
    @Query("notify", Bool.self)
    @Field("title", String.self)
    struct Publish {
      typealias Response = MutationResponse
    }

    @Get
    @Header("X-Trace-ID", String.self, default: "trace")
    struct Search {
      struct Query {
        let term: String
        let page: Int?

        @Key("created_after")
        let createdAfter: Date
      }

      @Serializable
      struct Response: Equatable {
        let items: [String]
      }
    }

    @Get
    struct ByAuthor {
      @Query
      struct Filter {
        @Key("author_id")
        let authorID: UUID

        let includeDrafts: Bool
      }

      typealias Response = MutationResponse
    }

    @Get
    struct ExternalSearch {
      @Query
      typealias Filter = ExternalPostQuery

      typealias Response = MutationResponse
    }

    @Post
    struct Review {
      typealias Content = PostReviewBody

      typealias Response = MutationResponse
    }

    @Post
    @Content(.form)
    @Field("email-address", String.self)
    @Field("password", String.self)
    struct Login {
      typealias Response = MutationResponse
    }

    @Post
    @Content(.binary, Data.self)
    struct Upload {
      typealias Response = MutationResponse
    }

    @Post
    @Content(.multipart(boundary: "fixture"))
    @Field("title", String.self)
    @Part("file", Data.self)
    struct Attach {
      typealias Response = MutationResponse
    }

    @Post
    @Content(.text, String.self)
    struct Comment {
      typealias Response = MutationResponse
    }
  }
}

@Path
private struct ContractAPI {
  @Path
  struct Users {
    @Post
    @Field("name", String.self)
    struct Create {
      @Response(.created)
      struct Response: Equatable {
        let id: UUID
      }

      @Response(.badRequest)
      struct ValidationError: Equatable {
        let message: String
      }
    }

    @Get
    struct Profile {
      @Serializable
      struct Response: Equatable {
        let name: String
      }

      @Response(.notFound)
      struct NotFound: Equatable {
        let message: String
      }
    }

    @Delete
    struct Delete {
      @Response(.noContent)
      struct NoContent {}
    }
  }
}

private struct ExternalPostQuery {
  let term: String
  let limit: Int
}

private struct PostReviewBody: Codable, Equatable {
  let title: String
}

private actor RequestRecorder {
  private var request: HttpRequest?

  func record(_ request: HttpRequest) {
    self.request = request
  }

  func last() -> HttpRequest? {
    request
  }
}

private struct RecordingWrapper: HttpWrapper {
  let recorder: RequestRecorder
  var body = Data("ok".utf8)
  var status: HTTPStatusCode = .ok

  func send(
    _ request: HttpRequest,
    next: @Sendable (HttpRequest) async throws -> HttpResponse<Data>
  ) async throws -> HttpResponse<Data> {
    await recorder.record(request)
    return HttpResponse(body: body, status: status)
  }
}

private struct PassthroughWrapper: HttpWrapper {
  func send(
    _ request: HttpRequest,
    next: @Sendable (HttpRequest) async throws -> HttpResponse<Data>
  ) async throws -> HttpResponse<Data> {
    try await next(request)
  }
}

private extension WrapperKey {
  static let capture = WrapperKey("capture")
}

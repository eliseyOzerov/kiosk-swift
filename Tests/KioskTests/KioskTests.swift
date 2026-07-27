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

  func testAnyHTTPHeadersCompareNamesCaseInsensitively() {
    let contentType = AnyHttpHeader(name: "Content-Type", value: "application/json")
    let lowercase = AnyHttpHeader(name: "content-type", value: "application/json")

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
    XCTAssertEqual(erased(.contentType, .json), AnyHttpHeader(name: "Content-Type", value: "application/json"))
    XCTAssertEqual(erased(.accept, .json), AnyHttpHeader(name: "Accept", value: "application/json"))
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

  func testApiMacroConfigurationBuildsDefaultContext() {
    let api = ConfiguredAPI()

    XCTAssertEqual(api.context.url.host, "api.example.com")
    XCTAssertEqual(api.context.url.scheme, .http)
    XCTAssertEqual(api.context.url.port, .alternateHTTP)
    XCTAssertEqual(api.context.headers, [erased(.accept, .json)])
    XCTAssertEqual(api.context.wire.defaults[Bool.self], false)
    XCTAssertEqual(api.users.context.url.path.map(\.urlPathComponent), ["v1", "users"])
    XCTAssertEqual(api.users.context.headers, [erased(.accept, .json), erased(.authorization, "Bearer users")])
    XCTAssertEqual(api.users.context.wire.defaults[Bool.self], false)

    let hostOverride = ConfiguredAPI("staging.example.com")
    XCTAssertEqual(hostOverride.context.url.host, "staging.example.com")
    XCTAssertEqual(hostOverride.context.url.scheme, .https)
    XCTAssertEqual(hostOverride.context.headers, [erased(.accept, .json)])
    XCTAssertEqual(hostOverride.users.context.url.path.map(\.urlPathComponent), ["users"])
    XCTAssertEqual(hostOverride.users.context.headers, [erased(.accept, .json), erased(.authorization, "Bearer users")])

    let urlOverride = ConfiguredAPI(url: .host("local.example.com").adding(path: "preview"))
    XCTAssertEqual(urlOverride.context.url.host, "local.example.com")
    XCTAssertEqual(urlOverride.users.context.url.path.map(\.urlPathComponent), ["preview", "users"])

    let labeled = LabeledConfiguredAPI()
    XCTAssertEqual(labeled.context.url.host, "labeled.example.com")
  }

  func testApiProxyMethodsRebuildChildContexts() {
    let header = AnyHttpHeader(name: "X-Client", value: "kiosk")
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
      .adding(header: AnyHttpHeader(name: "X-Route", value: "users"))
      .search
      .adding(query: UrlQueryItem(name: "locale", value: "en"))
      .wrap(.capture, RecordingWrapper(recorder: recorder))

    _ = try await endpoint(q: "kiosk", page: 1)
    let lastRequest = await recorder.last()
    let recordedRequest = try XCTUnwrap(lastRequest)

    XCTAssertEqual(recordedRequest.headers, [AnyHttpHeader(name: "X-Route", value: "users")])
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

  func testPathAndMethodMacrosBuildAccessorsFromExtensions() {
    let apple = ExtensionDeclaredAPI(context: HttpContext(url: .host("example.com")))
      .auth
      .signIn
      .apple

    XCTAssertEqual(apple.context.url.path.map { $0.urlPathComponent }, ["auth", "sign-in", "apple"])
  }

  func testGetMacroBuildsRequestWithQueryParameters() async throws {
    let recorder = RequestRecorder()
    let api = StoreAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: recorder))
    )

    let data = try await api.users.search(q: "forge", page: 2)
    let recordedRequest = await recorder.last()
    let request = try XCTUnwrap(recordedRequest)

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

    _ = try await api.users.create(.init(name: "Ada", displayName: nil))
    let recordedRequest = await recorder.last()
    let request = try XCTUnwrap(recordedRequest)
    let body = try XCTUnwrap(request.body)
    let decoded = try JSONDecoder().decode(StoreAPI.Users.Create.Content.self, from: body)

    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["users", "create"])
    XCTAssertEqual(request.headers.last { $0.name == HttpHeaderKey<HTTPContentType>.contentType.name }, erased(.contentType, .json))
    XCTAssertEqual(decoded.name, "Ada")
    XCTAssertNil(decoded.displayName)
  }

  func testApiWireSpecDrivesGeneratedJSONContent() async throws {
    let recorder = RequestRecorder()
    let wire = WireSpec.json(
      fields: .snakeCase,
      values: .jsonDefault
        .date(.secondsSince1970)
        .bool(.string)
    )
    let api = StoreAPI(
      context: HttpContext(url: .host("example.com"))
        .wire(wire)
        .wrap(.capture, RecordingWrapper(recorder: recorder))
    )

    _ = try await api.users.timedCreate(
      .init(
        displayName: "Ada",
        createdAt: Date(timeIntervalSince1970: 1000),
        enabled: true
      )
    )
    let recordedRequest = await recorder.last()
    let request = try XCTUnwrap(recordedRequest)
    let body = try XCTUnwrap(request.body)
    let object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: body) as? [String: Any]
    )

    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.headers.last { $0.name == HttpHeaderKey<HTTPContentType>.contentType.name }, erased(.contentType, .json))
    XCTAssertEqual(object["display_name"] as? String, "Ada")
    XCTAssertEqual((object["created_at"] as? NSNumber)?.doubleValue, 1000)
    XCTAssertEqual(object["enabled"] as? String, "true")
  }

  func testScopedWireMacrosDriveGeneratedJSONContent() async throws {
    let recorder = RequestRecorder()
    let api = WiredAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: recorder))
    )

    _ = try await api.events.create(
      .init(
        displayName: "Ada",
        createdAt: Date(timeIntervalSince1970: 1000),
        tags: ["swift"]
      )
    )
    let recordedRequest = await recorder.last()
    let request = try XCTUnwrap(recordedRequest)
    let body = try XCTUnwrap(request.body)
    let object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: body) as? [String: Any]
    )

    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(object["display_name"] as? String, "Ada")
    XCTAssertEqual((object["created_at"] as? NSNumber)?.doubleValue, 1000)
    XCTAssertEqual(object["tags"] as? [String], ["swift"])
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
      erased(.contentType, .json),
      erased(.accept, .json),
      AnyHttpHeader(name: HttpHeaderKey<String>.ifNoneMatch.name, value: "etag-1"),
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
      .init(title: "New"),
      notify: true
    )
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "publish", "1970-01-01T00:00:00Z", "launch"])
    XCTAssertEqual(request.url.query, [
      UrlQueryItem(name: "notify", value: "true"),
    ])
    XCTAssertEqual(request.headers.last { $0.name == HttpHeaderKey<HTTPContentType>.contentType.name }, erased(.contentType, .json))

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
      erased(.contentType, .json),
      erased(.accept, .json),
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

    _ = try await api.posts.login(.init(emailAddress: "a@b.com", password: "secret"))
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    let formBody = try XCTUnwrap(request.body)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "login"])
    XCTAssertEqual(request.headers.last { $0.name == HttpHeaderKey<HTTPContentType>.contentType.name }, erased(.contentType, .form))
    XCTAssertEqual(String(data: formBody, encoding: .utf8), "email-address=a%40b.com&password=secret")

    let data = Data([0, 1, 2])
    _ = try await api.posts.upload(data)
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "upload"])
    XCTAssertEqual(request.headers.last { $0.name == HttpHeaderKey<HTTPContentType>.contentType.name }, erased(.contentType, .binary))
    XCTAssertEqual(request.body, data)

    _ = try await api.posts.attach(.init(title: "Attachment", file: Data("bytes".utf8)))
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    let multipartBody = try XCTUnwrap(request.body)
    let multipart = try XCTUnwrap(String(data: multipartBody, encoding: .utf8))
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "attach"])
    XCTAssertEqual(
      request.headers.last { $0.name == HttpHeaderKey<HTTPContentType>.contentType.name },
      erased(.contentType, .multipart(boundary: "fixture"))
    )
    XCTAssertTrue(multipart.contains("--fixture\r\nContent-Disposition: form-data; name=\"title\"\r\n\r\nAttachment\r\n"))
    XCTAssertTrue(multipart.contains("--fixture\r\nContent-Disposition: form-data; name=\"file\"\r\nContent-Type: application/octet-stream\r\n\r\nbytes\r\n"))
    XCTAssertTrue(multipart.hasSuffix("--fixture--\r\n"))

    _ = try await api.posts.comment("hello")
    recordedRequest = await recorder.last()
    request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.url.path.map { $0.urlPathComponent }, ["posts", "comment"])
    XCTAssertEqual(request.headers.last { $0.name == HttpHeaderKey<HTTPContentType>.contentType.name }, erased(.contentType, .text))
    XCTAssertEqual(request.body, Data("hello".utf8))
  }

  func testEndpointStructMacrosReturnDeclaredResults() async throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let createdBody = try JSONEncoder().encode(ContractAPI.Users.Create.Response(id: id))
    let createdAPI = ContractAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: RequestRecorder(), body: createdBody, status: .created))
    )

    let created = try await createdAPI.users.create(.init(name: "Ada"))
    XCTAssertEqual(created.id, id)

    let errorBody = try JSONEncoder().encode(
      ContractAPI.BadRequest(message: "Name is required")
    )
    let failedAPI = ContractAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: RequestRecorder(), body: errorBody, status: .badRequest))
    )

    do {
      _ = try await failedAPI.users.create(.init(name: ""))
      XCTFail("Expected bad request error")
    } catch let error as ContractAPI.BadRequest {
      XCTAssertEqual(error.message, "Name is required")
    } catch {
      XCTFail("Expected bad request error, got \(error)")
    }

    let profileBody = try JSONEncoder().encode(ContractAPI.Users.Profile.Response(name: "Ada"))
    let profileAPI = ContractAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: RequestRecorder(), body: profileBody))
    )

    let profile = try await profileAPI.users.profile()
    XCTAssertEqual(profile.name, "Ada")

    let deletedAPI = ContractAPI(
      context: HttpContext(url: .host("example.com"))
        .wrap(.capture, RecordingWrapper(recorder: RequestRecorder(), body: Data(), status: .noContent))
    )

    try await deletedAPI.users.delete()
  }
}

@Api
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

@Api
struct ExtensionDeclaredAPI {}

extension ExtensionDeclaredAPI {
  @Path
  struct Auth {}
}

extension ExtensionDeclaredAPI.Auth {
  @Path
  struct SignIn {}
}

extension ExtensionDeclaredAPI.Auth.SignIn {
  @Post
  struct Apple {
    typealias Response = Data
  }
}

@Api
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
    struct Create {
      @Wire
      struct Content: Equatable {
        let name: String

        @Key("display-name")
        let displayName: String?
      }

      typealias Response = Data
    }

    @Post
    struct TimedCreate {
      @Wire
      struct Content: Equatable {
        let displayName: String
        let createdAt: Date
        let enabled: Bool
      }

      typealias Response = Data
    }
  }
}

@Header(.accept, .json)
@Default(Bool.self, false)
@Api(.host("api.example.com").scheme(.http).port(.alternateHTTP).adding(path: "v1"))
private struct ConfiguredAPI {
  @Header(.authorization, "Bearer users")
  @Path
  struct Users {}
}

@Api(url: .host("labeled.example.com"))
private struct LabeledConfiguredAPI {}

@Codec(.json)
@Rename(.snakeCase)
@Format(Date.self, .secondsSince1970)
@Default(Array.self, [])
@Api
private struct WiredAPI {
  @Path
  struct Events {
    @Post
    struct Create {
      @Wire
      struct Content: Equatable {
        let displayName: String
        let createdAt: Date
        let tags: [String]
      }

      typealias Response = Data
    }
  }
}

@Header(.contentType, .json)
@Header(.accept, .json)
@Api
private struct ComprehensiveAPI {
  @Path
  struct Posts {
    @Wire
    struct MutationResponse: Equatable {
      let ok: Bool
    }

    @Path
    @Param("date", Date.self)
    @Param("slug", String.self)
    struct Post {
      typealias Response = Posts.MutationResponse

      @Get
      @Header(.ifNoneMatch)
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
    struct Publish {
      struct Content: Codable, Equatable {
        let title: String
      }

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

      @Wire
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
    @Header(.contentType, .form)
    struct Login {
      struct Content: HTTPContentKeyProviding {
        let emailAddress: String
        let password: String

        static let contentKeys = ["emailAddress": "email-address"]
      }

      typealias Response = MutationResponse
    }

    @Post
    @Header(.contentType, .binary)
    @Content(Data.self)
    struct Upload {
      typealias Response = MutationResponse
    }

    @Post
    @Header(.contentType, .multipart(boundary: "fixture"))
    struct Attach {
      struct Content {
        let title: String

        @Part
        let file: Data
      }

      typealias Response = MutationResponse
    }

    @Post
    @Header(.contentType, .text)
    @Content(String.self)
    struct Comment {
      typealias Response = MutationResponse
    }
  }
}

@Api
private struct ContractAPI {
  @Status(.badRequest)
  struct BadRequest: Error, Equatable, Codable {
    let message: String
  }

  @Path
  struct Users {
    @Post
    struct Create {
      struct Content: Codable, Equatable {
        let name: String
      }

      struct Response: Equatable, Codable {
        let id: UUID
      }
    }

    @Get
    struct Profile {
      @Wire
      struct Response: Equatable {
        let name: String
      }
    }

    @Delete
    struct Delete {}
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

private func erased<Value: Sendable>(_ key: HttpHeaderKey<Value>, _ value: Value) -> AnyHttpHeader {
  HttpHeader(key, value).erased
}

private extension WrapperKey {
  static let capture = WrapperKey("capture")
}

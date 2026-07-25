import Kiosk
import Foundation
import XCTest

final class KioskProofTests: XCTestCase {
	override func tearDown() {
		URLRequestCaptureProtocol.handler = nil
		super.tearDown()
	}

	func testAcceptHeaderReachesFinalURLRequest() async throws {
		let recorder = URLRequestRecorder()
		URLRequestCaptureProtocol.handler = { request in
			recorder.record(request)

			return (
				try XCTUnwrap(HTTPURLResponse(
					url: try XCTUnwrap(request.url),
					statusCode: HTTPStatusCode.ok.rawValue,
					httpVersion: nil,
					headerFields: nil
				)),
				Data("ok".utf8)
			)
		}

		let api = TransportProofAPI(context: HttpContext(
			session: URLSession(configuration: .kioskProof),
			url: .host("example.com")
		))

		_ = try await api.ping()

		let request = try recorder.last()
		XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), HTTPContentType.text.rawValue)
	}

	func testContentMetadataInheritsAndOverridesAcrossPathTree() async throws {
		let recorder = ProofRequestRecorder()
		let api = ContentProofAPI(
			context: HttpContext(url: .host("example.com"))
				.wrap(.proofCapture, ProofRecordingWrapper(recorder: recorder))
		)

		_ = try await api.rootDefault(.init(name: "Ada"))
		var request = try await recorder.last()
		XCTAssertEqual(request.headers.last { $0.name == HttpHeaderKey<HTTPContentType>.contentType.name }, erased(.contentType, .json))

		_ = try await api.forms.login(.init(email: "a@b.com"))
		request = try await recorder.last()
		XCTAssertEqual(request.headers.last { $0.name == HttpHeaderKey<HTTPContentType>.contentType.name }, erased(.contentType, .form))
		XCTAssertEqual(String(data: try XCTUnwrap(request.body), encoding: .utf8), "email=a%40b.com")

		_ = try await api.forms.override(Data([1, 2, 3]))
		request = try await recorder.last()
		XCTAssertEqual(request.headers.last { $0.name == HttpHeaderKey<HTTPContentType>.contentType.name }, erased(.contentType, .binary))
		XCTAssertEqual(request.body, Data([1, 2, 3]))
	}

	func testWrapAndUnwrapMacrosScopeRegisteredWrappers() async throws {
		let events = WrapperEventRecorder()
		let recorder = URLRequestRecorder()
		URLRequestCaptureProtocol.handler = { request in
			recorder.record(request)

			return (
				try XCTUnwrap(HTTPURLResponse(
					url: try XCTUnwrap(request.url),
					statusCode: HTTPStatusCode.ok.rawValue,
					httpVersion: nil,
					headerFields: nil
				)),
				Data("ok".utf8)
			)
		}

		let api = AuthPolicyProofAPI(
			context: HttpContext(
				session: URLSession(configuration: .kioskProof),
				url: .host("example.com")
			)
			.register(.auth, AuthorizationWrapper(events: events))
		)

		_ = try await api.auth.login(.init(email: "a@b.com", password: "secret"))

		var recordedEvents = await events.values()
		XCTAssertEqual(recordedEvents, [])
		XCTAssertNil(try recorder.last().value(forHTTPHeaderField: "Authorization"))

		_ = try await api.users.me()

		recordedEvents = await events.values()
		XCTAssertEqual(recordedEvents, ["auth"])
		XCTAssertEqual(try recorder.last().value(forHTTPHeaderField: "Authorization"), "Bearer proof")
	}

	func testMethodPathArgumentsAppendCustomEndpointSegments() async throws {
		let recorder = ProofRequestRecorder()
		let api = RuntimeProofAPI(
			context: HttpContext(url: .host("example.com"))
				.wrap(.proofCapture, ProofRecordingWrapper(recorder: recorder))
		)

		_ = try await api.users.customSearch()
		let request = try await recorder.last()
		XCTAssertEqual(request.url.path.map(\.urlPathComponent), ["users", "custom-search"])
	}

	func testApiMacroBuildsPathTreeLikeRootApiNamespace() {
		let api = ApiProofAPI(context: HttpContext(url: .host("example.com")))

		XCTAssertEqual(api.users.context.url.path.map(\.urlPathComponent), ["users"])
	}

	func testUnlabeledPathConvertsStructNamesToURLSegments() {
		let routes = CasePathProofAPI(context: HttpContext(url: .host("example.com")))

		XCTAssertEqual(routes.userProfiles.context.url.path.map(\.urlPathComponent), ["user-profiles"])
		XCTAssertEqual(routes.oAuthClients.context.url.path.map(\.urlPathComponent), ["o-auth-clients"])
		XCTAssertEqual(routes.manualOverride.context.url.path.map(\.urlPathComponent), ["manual-segment"])
	}

	func testManualHeadersTypeEncodesIntoGeneratedRequest() async throws {
		let recorder = ProofRequestRecorder()
		let api = RuntimeProofAPI(
			context: HttpContext(url: .host("example.com"))
				.wrap(.proofCapture, ProofRecordingWrapper(recorder: recorder))
		)

		_ = try await api.users.manualHeaders(headers: .init(traceID: "trace-1", empty: nil))
		let request = try await recorder.last()
		XCTAssertEqual(request.headers.last { $0.name == "traceID" }?.value, "trace-1")
		XCTAssertNil(request.headers.last { $0.name == "empty" })
	}

	func testManualNonJSONContentCanProvideCustomContentKeys() async throws {
		let recorder = ProofRequestRecorder()
		let api = RuntimeProofAPI(
			context: HttpContext(url: .host("example.com"))
				.wrap(.proofCapture, ProofRecordingWrapper(recorder: recorder))
		)

		_ = try await api.users.manualForm(.init(emailAddress: "a@b.com"))
		let request = try await recorder.last()
		XCTAssertEqual(request.headers.last { $0.name == HttpHeaderKey<HTTPContentType>.contentType.name }, erased(.contentType, .form))
		XCTAssertEqual(String(data: try XCTUnwrap(request.body), encoding: .utf8), "email-address=a%40b.com")
	}

	func testGeneratedEndpointThrowsUnexpectedStatusForUndeclaredStatus() async throws {
		let api = RuntimeProofAPI(
			context: HttpContext(url: .host("example.com"))
				.wrap(.proofCapture, ProofRecordingWrapper(
					recorder: ProofRequestRecorder(),
					body: Data("missing".utf8),
					status: .notFound
				))
		)

		do {
			_ = try await api.users.customSearch()
			XCTFail("Expected unexpected status")
		} catch HttpContext.Error.unexpectedStatus(let status, let data) {
			XCTAssertEqual(status, .notFound)
			XCTAssertEqual(String(data: data, encoding: .utf8), "missing")
		}
	}

	func testWrappersRunInOrderAndCanMutateGeneratedRequests() async throws {
		let events = WrapperEventRecorder()
		let recorder = ProofRequestRecorder()
		let context = HttpContext(url: .host("example.com"))
			.wrap(.proofOuter, EventWrapper(name: "outer", events: events))
			.wrap(.proofMutate, MutatingHeaderWrapper(events: events))
			.wrap(.proofCapture, ProofRecordingWrapper(recorder: recorder, events: events))

		let api = RuntimeProofAPI(context: context)
		_ = try await api.users.customSearch()

		let recordedEvents = await events.values()
		XCTAssertEqual(recordedEvents, [
			"enter outer",
			"enter mutate",
			"capture",
			"exit mutate",
			"exit outer",
		])
		let request = try await recorder.last()
		XCTAssertEqual(request.headers.last { $0.name == "X-Mutated" }?.value, "true")
	}

	func testGeneratedEndpointsAndHandwrittenContextUseSameWrapperPipeline() async throws {
		let generatedEvents = WrapperEventRecorder()
		let generatedRecorder = ProofRequestRecorder()
		let generatedContext = HttpContext(url: .host("example.com"))
			.wrap(.proofOuter, EventWrapper(name: "outer", events: generatedEvents))
			.wrap(.proofCapture, ProofRecordingWrapper(recorder: generatedRecorder, events: generatedEvents))

		let api = RuntimeProofAPI(context: generatedContext)
		_ = try await api.users.customSearch()

		let handwrittenEvents = WrapperEventRecorder()
		let handwrittenRecorder = ProofRequestRecorder()
		let handwrittenContext = HttpContext(url: .host("example.com"))
			.adding(path: "users")
			.adding(path: "custom-search")
			.wrap(.proofOuter, EventWrapper(name: "outer", events: handwrittenEvents))
			.wrap(.proofCapture, ProofRecordingWrapper(recorder: handwrittenRecorder, events: handwrittenEvents))

		_ = try await handwrittenContext.get()

		let generatedEventValues = await generatedEvents.values()
		let handwrittenEventValues = await handwrittenEvents.values()
		XCTAssertEqual(generatedEventValues, handwrittenEventValues)
		let generatedPath = try await generatedRecorder.last().url.path.map(\.urlPathComponent)
		let handwrittenPath = try await handwrittenRecorder.last().url.path.map(\.urlPathComponent)
		XCTAssertEqual(
			generatedPath,
			handwrittenPath
		)
	}
}

@Wrap(.auth)
@Header(.contentType, .json)
@Path
private struct AuthPolicyProofAPI {
	@Unwrap(.auth)
	@Path
	struct Auth {
		@Post("login")
		struct Login {
			struct Content: Codable {
				let email: String
				let password: String
			}

			typealias Response = Data
		}
	}

	@Path
	struct Users {
		@Get("me")
		struct Me {
			typealias Response = Data
		}
	}
}

@Header(.accept, .text)
@Path
private struct TransportProofAPI {
	@Get
	struct Ping {
		typealias Response = Data
	}
}

@Header(.contentType, .json)
@Path
private struct ContentProofAPI {
	@Post
	struct RootDefault {
		struct Content: Codable {
			let name: String
		}

		typealias Response = Data
	}

	@Header(.contentType, .form)
	@Path
	struct Forms {
		@Post
		struct Login {
			struct Content {
				let email: String
			}

			typealias Response = Data
		}

		@Post
		@Header(.contentType, .binary)
		@Content(Data.self)
		struct Override {
			typealias Response = Data
		}
	}
}

@Path
private struct RuntimeProofAPI {
	@Path
	struct Users {
		@Get("custom-search")
		struct CustomSearch {
			typealias Response = Data
		}

		@Get
		struct ManualHeaders {
			struct Headers {
				let traceID: String
				let empty: String?
			}

			typealias Response = Data
		}

		@Post
		@Header(.contentType, .form)
		struct ManualForm {
			struct Content: HTTPContentKeyProviding {
				let emailAddress: String

				static let contentKeys = ["emailAddress": "email-address"]
			}

			typealias Response = Data
		}
	}
}

@Api
private struct ApiProofAPI {
	@Path
	struct Users {}
}

@Path
private struct CasePathProofAPI {
	@Path
	struct UserProfiles {}

	@Path
	struct OAuthClients {}

	@Path("manual-segment")
	struct ManualOverride {}
}

private final class URLRequestRecorder: @unchecked Sendable {
	private let lock = NSLock()
	private var request: URLRequest?

	func record(_ request: URLRequest) {
		lock.lock()
		defer { lock.unlock() }
		self.request = request
	}

	func last() throws -> URLRequest {
		lock.lock()
		defer { lock.unlock() }
		return try XCTUnwrap(request)
	}
}

private final class URLRequestCaptureProtocol: URLProtocol {
	nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

	override class func canInit(with request: URLRequest) -> Bool {
		true
	}

	override class func canonicalRequest(for request: URLRequest) -> URLRequest {
		request
	}

	override func startLoading() {
		guard let handler = Self.handler else {
			client?.urlProtocol(self, didFailWithError: HttpContext.Error.invalidURL)
			return
		}

		do {
			let (response, data) = try handler(request)
			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			client?.urlProtocol(self, didLoad: data)
			client?.urlProtocolDidFinishLoading(self)
		} catch {
			client?.urlProtocol(self, didFailWithError: error)
		}
	}

	override func stopLoading() {}
}

private extension URLSessionConfiguration {
	static var kioskProof: URLSessionConfiguration {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [URLRequestCaptureProtocol.self]
		return configuration
	}
}

private actor ProofRequestRecorder {
	private var request: HttpRequest?

	func record(_ request: HttpRequest) {
		self.request = request
	}

	func last() throws -> HttpRequest {
		return try XCTUnwrap(request)
	}
}

private actor WrapperEventRecorder {
	private var events: [String] = []

	func append(_ event: String) {
		events.append(event)
	}

	func values() -> [String] {
		events
	}
}

private struct ProofRecordingWrapper: HttpWrapper {
	let recorder: ProofRequestRecorder
	var events: WrapperEventRecorder?
	var body = Data("ok".utf8)
	var status: HTTPStatusCode = .ok

	func send(
		_ request: HttpRequest,
		next: @Sendable (HttpRequest) async throws -> HttpResponse<Data>
	) async throws -> HttpResponse<Data> {
		if let events {
			await events.append("capture")
		}
		await recorder.record(request)
		return HttpResponse(body: body, status: status)
	}
}

private struct EventWrapper: HttpWrapper {
	let name: String
	let events: WrapperEventRecorder

	func send(
		_ request: HttpRequest,
		next: @Sendable (HttpRequest) async throws -> HttpResponse<Data>
	) async throws -> HttpResponse<Data> {
		await events.append("enter \(name)")
		let response = try await next(request)
		await events.append("exit \(name)")
		return response
	}
}

private struct MutatingHeaderWrapper: HttpWrapper {
	let events: WrapperEventRecorder

	func send(
		_ request: HttpRequest,
		next: @Sendable (HttpRequest) async throws -> HttpResponse<Data>
	) async throws -> HttpResponse<Data> {
		await events.append("enter mutate")
		var request = request
		request.headers.append(AnyHttpHeader(name: "X-Mutated", value: "true"))
		let response = try await next(request)
		await events.append("exit mutate")
		return response
	}
}

private struct AuthorizationWrapper: HttpWrapper {
	let events: WrapperEventRecorder

	func send(
		_ request: HttpRequest,
		next: @Sendable (HttpRequest) async throws -> HttpResponse<Data>
	) async throws -> HttpResponse<Data> {
		await events.append("auth")
		var request = request
		request.headers.append(AnyHttpHeader(name: HttpHeaderKey<String>.authorization.name, value: "Bearer proof"))
		return try await next(request)
	}
}

private func erased<Value: Sendable>(_ key: HttpHeaderKey<Value>, _ value: Value) -> AnyHttpHeader {
	HttpHeader(key, value).erased
}

private extension WrapperKey {
	static let proofCapture = WrapperKey("proof-capture")
	static let proofOuter = WrapperKey("proof-outer")
	static let proofMutate = WrapperKey("proof-mutate")
}

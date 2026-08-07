import Foundation

/// Fluent WebSocket context that builds and starts URLSessionWebSocketTask requests.
public struct WsContext: RequestContext {
  public var session: URLSession
  public var url: UrlBuilder
  public var headers: HttpHeaderStorage
  public var options: WsOptions

  public init(
    session: URLSession = .shared,
    url: UrlBuilder = .init(scheme: .wss),
    headers: HttpHeaderStorage = .init(),
    options: WsOptions = .init()
  ) {
    self.session = session
    self.url = url
    self.headers = headers
    self.options = options
  }
}

extension WsContext {
  public enum Error: Swift.Error {
    case missingHost
    case invalidURL
  }

  public func session(_ session: URLSession) -> WsContext {
    var context = self
    context.session = session
    return context
  }

  public func connect() throws -> URLSessionWebSocketTask {
    var request = URLRequest(url: try makeURL())
    options.apply(to: &request)

    for header in headers {
      request.setValue(header.value, forHTTPHeaderField: header.name)
    }

    let task = session.webSocketTask(with: request)
    if let maximumMessageSize = options.maximumMessageSize {
      task.maximumMessageSize = maximumMessageSize
    }

    task.resume()
    return task
  }
}

/// URLRequest and message-size option overrides for WebSocket connections.
public struct WsOptions: Sendable {
  /// Overrides the idle timeout for the WebSocket upgrade request.
  public var timeoutInterval: TimeInterval?

  /// Allows the WebSocket upgrade request to use cellular interfaces.
  public var allowsCellularAccess: Bool?

  /// Allows the WebSocket upgrade request to use expensive interfaces, such as cellular or personal hotspot.
  public var allowsExpensiveNetworkAccess: Bool?

  /// Allows the WebSocket upgrade request to use constrained interfaces, such as Low Data Mode networks.
  public var allowsConstrainedNetworkAccess: Bool?

  /// Overrides the maximum received WebSocket message size.
  public var maximumMessageSize: Int?

  public init(
    timeoutInterval: TimeInterval? = nil,
    allowsCellularAccess: Bool? = nil,
    allowsExpensiveNetworkAccess: Bool? = nil,
    allowsConstrainedNetworkAccess: Bool? = nil,
    maximumMessageSize: Int? = nil
  ) {
    self.timeoutInterval = timeoutInterval
    self.allowsCellularAccess = allowsCellularAccess
    self.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
    self.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
    self.maximumMessageSize = maximumMessageSize
  }
}

extension WsContext {
  func makeURL() throws -> URL {
    do {
      return try url.build()
    } catch UrlBuilder.Error.missingHost {
      throw Error.missingHost
    } catch UrlBuilder.Error.invalidURL {
      throw Error.invalidURL
    }
  }
}

extension WsOptions {
  fileprivate func apply(to request: inout URLRequest) {
    if let timeoutInterval {
      request.timeoutInterval = timeoutInterval
    }
    if let allowsCellularAccess {
      request.allowsCellularAccess = allowsCellularAccess
    }
    if let allowsExpensiveNetworkAccess {
      request.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
    }
    if let allowsConstrainedNetworkAccess {
      request.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
    }
  }
}

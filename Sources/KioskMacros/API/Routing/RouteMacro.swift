import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct RouteMacro: MemberMacro, PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let defaultContextExpression = RouteExpansion.defaultContextExpression(for: declaration)
    let contextExpression = RouteExpansion.contextExpression(for: declaration)
    let parameterBinder = RouteExpansion.parameterBinder(in: declaration, context: context)

    return [
      """
      var context: HttpContext
      """,
    ] + [
      """
      init(context: HttpContext = \(raw: defaultContextExpression)) {
          let context = \(raw: contextExpression)
          self.context = context
      }
      """,
      """
      init(_ host: String) {
          self.init(host: host)
      }
      """,
      """
      init(host: String) {
          self.init(url: .host(host))
      }
      """,
      """
      init(url: UrlBuilder) {
          self.init(context: HttpContext(url: url))
      }
      """,
    ] + ContextProxyExpansion.members + parameterBinder
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard node.attributeName.trimmedDescription == "Path",
      RouteAccessorExpansion.canGeneratePeerAccessor(in: context),
      let declaration = declaration.as(StructDeclSyntax.self)
    else {
      return []
    }

    return RouteAccessorExpansion.pathAccessor(for: declaration, attribute: node, context: context)
  }
}

enum ContextProxyExpansion {
  static var members: [DeclSyntax] {
    [
      """
      func with(context: HttpContext) -> Self {
          Self(context: context)
      }
      """,
      """
      func url(_ url: UrlBuilder) -> Self {
          Self(context: context.url(url))
      }
      """,
      """
      func scheme(_ scheme: UrlScheme) -> Self {
          Self(context: context.scheme(scheme))
      }
      """,
      """
      func host(_ host: String?) -> Self {
          Self(context: context.host(host))
      }
      """,
      """
      func port(_ port: UrlPort?) -> Self {
          Self(context: context.port(port))
      }
      """,
      """
      func path(_ path: [UrlPathComponent]) -> Self {
          Self(context: context.path(path))
      }
      """,
      """
      func query(_ query: [UrlQueryItem]) -> Self {
          Self(context: context.query(query))
      }
      """,
      """
      func headers(_ headers: HttpHeaderStorage) -> Self {
          Self(context: context.headers(headers))
      }
      """,
      """
      func headers(_ headers: [AnyHttpHeader]) -> Self {
          Self(context: context.headers(headers))
      }
      """,
      """
      func options(_ options: HttpOptions) -> Self {
          Self(context: context.options(options))
      }
      """,
      """
      func timeout(_ timeout: HttpTimeout) -> Self {
          Self(context: context.timeout(timeout))
      }
      """,
      """
      func timeout(request: Double? = nil, resource: Double? = nil) -> Self {
          Self(context: context.timeout(request: request, resource: resource))
      }
      """,
      """
      func adding(path component: UrlPathComponent) -> Self {
          Self(context: context.adding(path: component))
      }
      """,
      """
      func adding(query item: UrlQueryItem) -> Self {
          Self(context: context.adding(query: item))
      }
      """,
      """
      func adding(query items: [UrlQueryItem]) -> Self {
          Self(context: context.adding(query: items))
      }
      """,
      """
      func adding(header: AnyHttpHeader) -> Self {
          Self(context: context.adding(header: header))
      }
      """,
      """
      func adding<Value: Sendable>(header: HttpHeader<Value>) -> Self {
          Self(context: context.adding(header: header))
      }
      """,
      """
      func set(header: AnyHttpHeader) -> Self {
          Self(context: context.adding(header: header))
      }
      """,
      """
      func set<Value: Sendable>(header: HttpHeader<Value>) -> Self {
          Self(context: context.adding(header: header))
      }
      """,
      """
      func adding(headers: [AnyHttpHeader]) -> Self {
          Self(context: context.adding(headers: headers))
      }
      """,
      """
      func adding(headers: HttpHeaderStorage) -> Self {
          Self(context: context.adding(headers: headers))
      }
      """,
      """
      func wire(_ wire: WireSpec) -> Self {
          Self(context: context.wire(wire))
      }
      """,
      """
      func codec(_ codec: WireCodec) -> Self {
          Self(context: context.codec(codec))
      }
      """,
      """
      func rename(_ renaming: FieldRenamingStrategy) -> Self {
          Self(context: context.rename(renaming))
      }
      """,
      """
      func format<Value>(_ type: Value.Type, _ format: WireFormat) -> Self {
          Self(context: context.format(type, format))
      }
      """,
      """
      func wireDefault<Value>(_ type: Value.Type, _ value: Value) -> Self {
          Self(context: context.wireDefault(type, value))
      }
      """,
      """
      func errors(_ errors: HttpErrorDecoding) -> Self {
          Self(context: context.errors(errors))
      }
      """,
      """
      func accept(_ accept: HTTPContentType) -> Self {
          Self(context: context.accept(accept))
      }
      """,
      """
      func throwing<Failure: Decodable & Sendable>(
          _ failure: Failure.Type,
          for statusCode: HTTPStatusCode
      ) -> Self {
          Self(context: context.throwing(Failure.self, for: statusCode))
      }
      """,
      """
      func throwing<Failure: Decodable & Sendable>(
          _ failure: Failure.Type,
          for statusClass: HTTPStatusClass
      ) -> Self {
          Self(context: context.throwing(Failure.self, for: statusClass))
      }
      """,
      """
      func register(_ key: WrapperKey, _ wrapper: any HttpWrapper) -> Self {
          Self(context: context.register(key, wrapper))
      }
      """,
      """
      func register(_ key: WrapperKey, _ makeWrapper: @escaping @Sendable (Self) -> any HttpWrapper) -> Self {
          Self(context: context.register(key) {
              makeWrapper(Self(context: context))
          })
      }
      """,
      """
      func wrap(_ key: WrapperKey, _ wrapper: (any HttpWrapper)? = nil, activate: Bool = true) -> Self {
          Self(context: context.wrap(key, wrapper, activate: activate))
      }
      """,
      """
      func wrap(_ key: WrapperKey, activate: Bool = true, _ makeWrapper: @escaping @Sendable (Self) -> any HttpWrapper) -> Self {
          Self(context: context.wrap(key, activate: activate) {
              makeWrapper(Self(context: context))
          })
      }
      """,
      """
      func unwrap(_ key: WrapperKey) -> Self {
          Self(context: context.unwrap(key))
      }
      """,
      """
      func unwrapped() -> Self {
          Self(context: context.unwrapped())
      }
      """,
    ]
  }
}

enum RouteExpansion {
  static func defaultContextExpression(for declaration: some DeclGroupSyntax) -> String {
    guard let attribute = declaration.attribute(named: "Api"),
      let configuration = ApiAttribute(attribute)
    else {
      return ".init()"
    }

    return configuration.contextExpression
  }

  static func contextExpression(for declaration: some DeclGroupSyntax) -> String {
    decoratedContextExpression("context", for: declaration)
  }

  static func children(
    in declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext
  ) -> [RouteChild] {
    declaration.memberBlock.members.compactMap { member -> RouteChild? in
      guard let child = member.decl.as(StructDeclSyntax.self) else { return nil }

      let childName = child.name.text
      let accessor = childName.lowercasedFirst
      let parameters = RouteParamArgument.all(
        in: child,
        context: context
      )

      if let routeAttribute = pathAttribute(in: child) {
        let path = RoutePathArgument(routeAttribute).path ?? (parameters.isEmpty ? childName.urlPathSegment : nil)
        return RouteChild(
          childName: childName,
          accessor: accessor,
          path: path,
          declaration: child
        )
      }

      guard let methodAttribute = HTTPMethodAttribute(child, childName: childName) else { return nil }

      return RouteChild(
        childName: childName,
        accessor: accessor,
        path: methodAttribute.path,
        declaration: child
      )
    }
  }

  static func parameterBinder(
    in declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext
  ) -> [DeclSyntax] {
    let parameters = RouteParamArgument.all(in: declaration, context: context)
    guard !parameters.isEmpty else {
      return []
    }

    let signature = parameters.map { "\($0.label): \($0.type)" }.joined(separator: ", ")
    let expression = baseContextExpression(path: nil, parameters: parameters, child: true)
    return [
      """
      func callAsFunction(\(raw: signature)) -> Self {
          Self(context: \(raw: expression))
      }
      """
    ]
  }

  static func contextExpression(
    path: String?,
    parameters: [RouteParamArgument],
    declaration: some DeclGroupSyntax
  ) -> String {
    decoratedContextExpression(
      baseContextExpression(path: path, parameters: parameters, child: true),
      for: declaration
    )
  }

  static func baseContextExpression(
    path: String?,
    parameters: [RouteParamArgument],
    child: Bool = false
  ) -> String {
    var expression = child ? "context.child()" : "context"

    if let path {
      expression += "\n    .adding(path: \"\(path)\")"
    }

    for parameter in parameters {
      expression += "\n    .adding(path: \(parameter.label))"
    }

    return expression
  }

  private static func decoratedContextExpression(
    _ expression: String,
    for declaration: some DeclGroupSyntax
  ) -> String {
    var expression = expression

    for element in declaration.attributes {
      guard let attribute = element.as(AttributeSyntax.self) else {
        continue
      }

      switch attribute.attributeName.trimmedDescription {
      case "Header":
        if let header = StaticHeaderAttribute(attribute) {
          expression += "\n    .adding(header: \(header.header))"
        }
      case "Timeout":
        if let timeout = TimeoutAttribute(attribute) {
          expression +=
            "\n    .timeout(request: \(timeout.request), resource: \(timeout.resource))"
        }
      case "Accept":
        if let accept = AcceptAttribute(attribute) {
          expression += "\n    .accept(\(accept.contentType))"
        }
      case "Wrap":
        if let wrapper = WrapperAttribute(attribute) {
          expression += "\n    .wrap(\(wrapper.key))"
        }
      case "Unwrap":
        if let wrapper = WrapperAttribute(attribute) {
          expression += "\n    .unwrap(\(wrapper.key))"
        }
      case "Codec":
        if let codec = CodecAttribute(attribute) {
          expression += "\n    .codec(\(codec.codec))"
        }
      case "Rename":
        if let rename = RenameAttribute(attribute) {
          expression += "\n    .rename(\(rename.renaming))"
        }
      case "Format":
        if let format = ScopedFormatAttribute(attribute) {
          expression += "\n    .format(\(format.type).self, \(format.format))"
        }
      case "Default":
        if let defaultValue = ScopedDefaultAttribute(attribute) {
          expression += "\n    .wireDefault(\(defaultValue.type).self, \(defaultValue.value))"
        }
      default:
        break
      }
    }

    for status in StatusRegistration.all(in: declaration) {
      expression += "\n    .throwing(\(status.type).self, for: \(status.statusExpression))"
    }

    return expression
  }

  private static func attribute(named name: String, in declaration: some DeclGroupSyntax)
    -> AttributeSyntax?
  {
    declaration.attributes.lazy.compactMap { element in
      element.as(AttributeSyntax.self)
    }
    .first { attribute in
      attribute.attributeName.trimmedDescription == name
    }
  }

  private static func pathAttribute(in declaration: some DeclGroupSyntax) -> AttributeSyntax? {
    attribute(named: "Path", in: declaration)
  }
}

enum RouteAccessorExpansion {
  static func canGeneratePeerAccessor(in context: some MacroExpansionContext) -> Bool {
    context.lexicalContext.contains { syntax in
      syntax.as(StructDeclSyntax.self) != nil || syntax.as(ExtensionDeclSyntax.self) != nil
    }
  }

  static func pathAccessor(
    for declaration: StructDeclSyntax,
    attribute: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [DeclSyntax] {
    let childName = declaration.name.text
    let parameters = RouteParamArgument.all(in: declaration, context: context)
    let path = RoutePathArgument(attribute).path ?? (parameters.isEmpty ? childName.urlPathSegment : nil)

    return [accessor(childName: childName, accessor: childName.lowercasedFirst, path: path)]
  }

  static func methodAccessor(
    for declaration: StructDeclSyntax,
    attribute: AttributeSyntax,
    methodName: String
  ) -> [DeclSyntax] {
    let childName = declaration.name.text
    let accessorName = childName.lowercasedFirst
    let path = RoutePathArgument(attribute).path ?? defaultMethodPath(
      childName: childName,
      accessorName: accessorName,
      methodName: methodName
    )

    return [accessor(childName: childName, accessor: accessorName, path: path)]
  }

  private static func defaultMethodPath(
    childName: String,
    accessorName: String,
    methodName: String
  ) -> String? {
    accessorName == methodName.lowercased() ? nil : childName.urlPathSegment
  }

  private static func accessor(childName: String, accessor: String, path: String?) -> DeclSyntax {
    let expression = RouteExpansion.baseContextExpression(path: path, parameters: [], child: true)
    return """
      var \(raw: accessor): \(raw: childName) {
          \(raw: childName)(context: \(raw: expression))
      }
      """
  }
}

private struct StatusRegistration {
  let type: String
  let statusExpression: String

  static func all(in declaration: some DeclGroupSyntax) -> [StatusRegistration] {
    declaration.memberBlock.members.compactMap { member in
      guard let nested = member.decl.as(StructDeclSyntax.self),
        let attribute = nested.attributes.lazy.compactMap({ $0.as(AttributeSyntax.self) }).first(where: {
          $0.attributeName.trimmedDescription == "Status"
        }),
        let status = StatusAttribute(attribute)
      else {
        return nil
      }

      return StatusRegistration(type: nested.name.text, statusExpression: status.statusExpression)
    }
  }
}

/// Stored child route or endpoint metadata synthesized into a generated API route tree.
struct RouteChild {
  let childName: String
  let accessor: String
  let path: String?
  let declaration: StructDeclSyntax

  var storedProperty: DeclSyntax {
    """
    var \(raw: accessor): \(raw: childName)
    """
  }

  var initializer: String {
    let expression = RouteExpansion.baseContextExpression(
      path: path,
      parameters: [],
      child: true
    )
    return "        self.\(accessor) = \(childName)(context: \(expression))"
  }
}

private struct RoutePathArgument {
  let path: String?

  init(_ attribute: AttributeSyntax) {
    path = Self.unlabeledStringLiteral(in: attribute.description)
  }

  private static func unlabeledStringLiteral(in text: String) -> String? {
    guard let open = text.firstIndex(of: "("),
      let close = text.lastIndex(of: ")"),
      open < close
    else {
      return nil
    }

    let body = text[text.index(after: open)..<close]
    guard let first = body.split(separator: ",", maxSplits: 1).first else {
      return nil
    }

    let argument = first.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !argument.contains(":") else {
      return nil
    }

    return firstStringLiteral(in: argument)
  }

  private static func firstStringLiteral(in text: String) -> String? {
    guard let start = text.firstIndex(of: "\"") else {
      return nil
    }

    let remainder = text[text.index(after: start)...]
    guard let end = remainder.firstIndex(of: "\"") else {
      return nil
    }

    return String(remainder[..<end])
  }
}

private struct ApiAttribute {
  let url: String

  init?(_ attribute: AttributeSyntax) {
    guard let url = Self.expression(in: attribute) else {
      return nil
    }

    self.url = url
  }

  var contextExpression: String {
    "HttpContext(url: \(url))"
  }

  private static func expression(in attribute: AttributeSyntax) -> String? {
    guard case .argumentList(let arguments) = attribute.arguments else {
      return nil
    }

    for argument in arguments {
      guard argument.label == nil || argument.label?.text == "url" else {
        continue
      }
      return argument.expression.trimmedDescription
    }

    return nil
  }
}

struct RouteParamArgument {
  let label: String
  let type: String

  static func all(
    in declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext
  ) -> [RouteParamArgument] {
    let parameters: [RouteParamArgument] = declaration.attributes.compactMap { element in
      guard let attribute = element.as(AttributeSyntax.self),
        attribute.attributeName.trimmedDescription == "Param"
      else {
        return nil
      }

      guard let parameter = RouteParamArgument(attribute) else {
        context.diagnose(
          Diagnostic(
            node: Syntax(attribute),
            message: ApiUtilsMacroDiagnostic(
              "Expected @Param(\"label\", Type.self).",
              id: "invalid-route-param-attribute"
            )
          )
        )
        return nil
      }

      guard parameter.label.isSimpleSwiftIdentifier else {
        context.diagnose(
          Diagnostic(
            node: Syntax(attribute),
            message: ApiUtilsMacroDiagnostic(
              "@Param label '\(parameter.label)' must be a Swift identifier.",
              id: "invalid-route-param-label"
            )
          )
        )
        return nil
      }

      return parameter
    }

    let duplicateLabels = Dictionary(grouping: parameters, by: \.label)
      .filter { $0.value.count > 1 }
      .keys

    for label in duplicateLabels {
      context.diagnose(
        Diagnostic(
          node: Syntax(declaration),
          message: ApiUtilsMacroDiagnostic(
            "Multiple @Param attributes resolve to the same label '\(label)'. Provide explicit labels.",
            id: "duplicate-route-param-label"
          )
        )
      )
    }

    return parameters
  }

  init?(_ attribute: AttributeSyntax) {
    guard let argument = LabeledTypeAttribute(attribute) else {
      return nil
    }

    label = argument.label
    type = argument.type
  }
}

private struct HTTPMethodAttribute {
  let path: String?

  init?(_ declaration: some DeclGroupSyntax, childName: String) {
    guard let attribute = Self.attribute(in: declaration) else {
      return nil
    }

    path = RoutePathArgument(attribute).path ?? Self.defaultPath(
      childName: childName,
      methodName: attribute.attributeName.trimmedDescription
    )
  }

  private static func defaultPath(childName: String, methodName: String) -> String? {
    let accessor = childName.lowercasedFirst
    return accessor == methodName.lowercased() ? nil : childName.urlPathSegment
  }

  private static func attribute(in declaration: some DeclGroupSyntax) -> AttributeSyntax? {
    declaration.attributes.lazy.compactMap { element in
      element.as(AttributeSyntax.self)
    }
    .first { attribute in
      Self.names.contains(attribute.attributeName.trimmedDescription)
    }
  }

  private static let names = ["Get", "Post", "Put", "Patch", "Delete"]
}

private extension String {
  var lowercasedFirst: String {
    guard let first else { return self }
    return first.lowercased() + String(dropFirst())
  }

  var urlPathSegment: String {
    guard !isEmpty else { return self }

    var result = ""
    for character in self {
      if character.isUppercase {
        if !result.isEmpty {
          result.append("-")
        }
        result.append(character.lowercased())
      } else {
        result.append(character)
      }
    }

    return result
  }
}

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

enum HTTPMethodBody {
  enum Method: String {
    case get
    case post
    case put
    case patch
    case delete
  }

  static func expand(
    _ method: Method,
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax
  ) throws -> [CodeBlockItemSyntax] {
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      return []
    }

    let parameters = function.signature.parameterClause.parameters
    let queries = parameters.compactMap(QueryParameter.init)
    let content = parameters.compactMap(ContentParameter.init).first
    let returnType = ReturnType(function)
    let methodPath = RouteAttribute(node).path
    let requestExpression = requestExpression(path: methodPath, queries: queries)

    return [
      "let requestContext = \(raw: requestExpression)",
      "\(raw: responseExpression(method: method, content: content, returnType: returnType))",
    ]
  }

  static func expand(
    _ method: Method,
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard declaration.as(StructDeclSyntax.self) != nil else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: ApiUtilsMacroDiagnostic(
            "@\(method.attributeName) can only generate endpoint members for structs.",
            id: "method-macro-requires-struct"
          )
        )
      )
      return []
    }

    let contract = EndpointContract(declaration, context: context)
    let parameters = contract.callParameters
    let returnClause = contract.callReturnClause
    let parameterBinder = RouteExpansion.parameterBinder(in: declaration, context: context)
    let setup = contract.requestContextSetup
    let response = endpointResponseExpression(method: method, contract: contract)

    return contract.generatedMembers + [
      """
      var context: HttpContext
      """,
      """
      init(context: HttpContext) {
          let context = \(raw: RouteExpansion.contextExpression(for: declaration))
          self.context = context
      }
      """,
    ] + ContextProxyExpansion.members + parameterBinder + [
      """
      func callAsFunction(\(raw: parameters)) async throws\(raw: returnClause) {
          \(raw: setup)
          \(raw: response)
      }
      """,
    ]
  }

  static func expand(
    _ method: Method,
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard RouteAccessorExpansion.canGeneratePeerAccessor(in: context),
      let declaration = declaration.as(StructDeclSyntax.self)
    else {
      return []
    }

    return RouteAccessorExpansion.methodAccessor(
      for: declaration,
      attribute: node,
      methodName: method.attributeName
    )
  }

  private static func requestExpression(path: String?, queries: [QueryParameter]) -> String {
    var expression = "context"
    if let path {
      expression += "\n    .adding(path: \"\(path)\")"
    }

    for query in queries {
      expression +=
        "\n    .adding(query: UrlQueryItem(name: \"\(query.name)\", value: \(query.localName)))"
    }

    return expression
  }

  private static func responseExpression(
    method: Method, content: ContentParameter?, returnType: ReturnType
  ) -> String {
    let call = methodCall(method: method, content: content, returnType: returnType)
    switch returnType {
    case .void:
      return "_ = try await \(call)"
    case .data, .decodable:
      return "return try await \(call).body"
    }
  }

  private static func methodCall(method: Method, content: ContentParameter?, returnType: ReturnType)
    -> String
  {
    let methodName = method.rawValue

    if let content {
      switch returnType {
      case .void, .data:
        return "requestContext.data(for: .\(methodName), content: \(content.localName))"
      case .decodable(let type):
        return "requestContext.decode(\(type).self, from: requestContext.data(for: .\(methodName), content: \(content.localName)))"
      }
    }

    switch returnType {
    case .void, .data:
      return "requestContext.\(methodName)()"
    case .decodable(let type):
      switch method {
      case .get, .delete:
        return "requestContext.\(methodName)(as: \(type).self)"
      case .post, .put, .patch:
        return "requestContext.decode(\(type).self, from: requestContext.\(methodName)())"
      }
    }
  }

  private static func endpointResponseExpression(method: Method, contract: EndpointContract)
    -> String
  {
    let responseCall: String
    if contract.hasContent {
      responseCall = "try await requestContext.data(for: .\(method.rawValue), content: \(contract.contentExpression))"
    } else {
      responseCall = "try await requestContext.data(for: .\(method.rawValue))"
    }

    let successCase = contract.resultCases[0]

    return """
      let response = \(responseCall)
      try requestContext.validate(response)
      \(contract.responseReturnExpression(for: successCase))
      """
  }
}

private enum ReturnType {
  case void
  case data
  case decodable(String)

  init(_ function: FunctionDeclSyntax) {
    guard let type = function.signature.returnClause?.type.trimmedDescription else {
      self = .void
      return
    }

    switch type {
    case "Void", "()":
      self = .void
    case "Data":
      self = .data
    default:
      self = .decodable(type)
    }
  }
}

private struct EndpointContract {
  let contentType: String?
  let contentParameterName: String
  let contentFields: [EndpointField]
  let generatesContentType: Bool
  let queryType: String?
  let queryKeys: [String: String]
  let queryFields: [EndpointField]
  let generatesQueryType: Bool
  let headerType: String?
  let headerFields: [HeaderField]
  let staticHeaders: [StaticHeaderAttribute]
  let generatesHeaderType: Bool
  let resultCases: [EndpointResultCase]

  init(_ declaration: some DeclGroupSyntax, context: some MacroExpansionContext) {
    let contentAttribute = declaration.attribute(named: "Content").flatMap(ContentAttribute.init)
    contentFields = []
    let hasContentType = declaration.hasNestedType(named: "Content")
    let hasSingleValueContent = contentAttribute != nil
    generatesContentType = contentFields.isEmpty == false && !hasContentType && !hasSingleValueContent

    if contentFields.isEmpty == false,
      hasContentType || hasSingleValueContent
    {
      context.diagnose(
        Diagnostic(
            node: Syntax(declaration),
            message: ApiUtilsMacroDiagnostic(
            "Use either a nested Content type, a Content typealias, or @Content(Value.self), not more than one.",
            id: "content-fields-conflict-with-content-type"
          )
        )
      )
    }

    if let type = contentAttribute?.type {
      contentType = type
      contentParameterName = "content"
    } else if let type = declaration.nestedTypeAlias(named: "Content") {
      contentType = type
      contentParameterName = "content"
    } else if hasContentType {
      contentType = "Content"
      contentParameterName = "content"
    } else if generatesContentType {
      contentType = "Content"
      contentParameterName = "content"
    } else {
      contentType = nil
      contentParameterName = "content"
    }

    queryFields = EndpointField.all(named: "Query", in: declaration, context: context)
    headerFields = HeaderField.all(in: declaration, context: context)
    staticHeaders = StaticHeaderAttribute.all(in: declaration)
    let queryTypes = EndpointContractType.all(markedBy: "Query", in: declaration)
    if queryTypes.count > 1 {
      context.diagnose(
        Diagnostic(
          node: Syntax(declaration),
          message: ApiUtilsMacroDiagnostic(
            "Endpoint structs can only have one nested @Query type.",
            id: "duplicate-endpoint-query-types"
          )
        )
      )
    }

    let hasQueryType = declaration.hasNestedType(named: "Query")
    let hasHeaderType = declaration.hasNestedType(named: "Headers")
    generatesQueryType = queryFields.isEmpty == false && !hasQueryType && queryTypes.isEmpty
    generatesHeaderType = headerFields.isEmpty == false && !hasHeaderType

    if queryFields.isEmpty == false,
      hasQueryType || queryTypes.isEmpty == false
    {
      context.diagnose(
        Diagnostic(
          node: Syntax(declaration),
          message: ApiUtilsMacroDiagnostic(
            "Use either @Query attributes or a nested Query type, not both.",
            id: "query-attributes-conflict-with-query-type"
          )
        )
      )
    }

    if headerFields.isEmpty == false,
      hasHeaderType
    {
      context.diagnose(
        Diagnostic(
          node: Syntax(declaration),
          message: ApiUtilsMacroDiagnostic(
            "Use either @Header attributes or a nested Headers type, not both.",
            id: "header-attributes-conflict-with-headers-type"
          )
        )
      )
    }

    if let type = queryTypes.first {
      queryType = type.type
    } else if let type = declaration.nestedTypeAlias(named: "Query") {
      queryType = type
    } else if hasQueryType {
      queryType = "Query"
    } else if generatesQueryType {
      queryType = "Query"
    } else {
      queryType = nil
    }

    if let type = declaration.nestedTypeAlias(named: "Headers") {
      headerType = type
    } else if hasHeaderType {
      headerType = "Headers"
    } else if generatesHeaderType {
      headerType = "Headers"
    } else {
      headerType = nil
    }

    var queryKeys = declaration.nestedKeys(for: queryTypes.first?.name ?? "Query")
    if generatesQueryType {
      for field in queryFields where field.wireLabel != field.label {
        queryKeys[field.label] = field.wireLabel
      }
    }
    self.queryKeys = queryKeys

    let resultCases = [EndpointResultCase.defaultResponse(in: declaration)]
    EndpointResultCase.diagnoseDuplicates(resultCases, in: declaration, context: context)
    self.resultCases = resultCases
  }

  var hasContent: Bool {
    contentType != nil
  }

  var hasQuery: Bool {
    queryType != nil
  }

  var hasHeaders: Bool {
    headerType != nil
  }

  var generatedMembers: [DeclSyntax] {
    var members: [DeclSyntax] = []

    if generatesContentType {
      let fields = contentFields
        .map { "        let \($0.label): \($0.type)" }
        .joined(separator: "\n")
      let keyEntries = contentFields
        .filter { $0.wireLabel != $0.label }
        .map { "\"\($0.label)\": \"\($0.wireLabel)\"" }
        .joined(separator: ", ")
      let contentKeysExpression = keyEntries.isEmpty ? ":" : keyEntries
      let codingKeys = contentFields
        .map { field -> String in
          if field.wireLabel == field.label {
            return "        case \(field.label)"
          }

          return "        case \(field.label) = \"\(field.wireLabel)\""
        }
        .joined(separator: "\n")

      members.append(
        """
        struct Content: WireCodable, HTTPContentKeyProviding {
        \(raw: fields)

            static let contentKeys: [String: String] = [\(raw: contentKeysExpression)]

            enum CodingKeys: String, CodingKey {
        \(raw: codingKeys)
            }
        }
        """
      )
    }

    if generatesQueryType {
      let fields = queryFields
        .map { "        let \($0.label): \($0.type)" }
        .joined(separator: "\n")

      members.append(
        """
        struct Query {
        \(raw: fields)
        }
        """
      )
    }

    if generatesHeaderType {
      let fields = headerFields
        .map { "        let \($0.label): \($0.type)" }
        .joined(separator: "\n")

      members.append(
        """
        struct Headers {
        \(raw: fields)
        }
        """
      )
    }

    let cases = resultCases
      .map(\.caseDeclaration)
      .joined(separator: "\n")
    members.append(
      """
      enum Result {
      \(raw: cases)
      }
      """
    )

    return members
  }

  var callReturnClause: String {
    guard resultCases.count == 1 else {
      return " -> Result"
    }

    switch resultCases[0].payload {
    case .void:
      return ""
    case .data:
      return " -> Data"
    case .decodable(let type):
      return " -> \(type)"
    }
  }

  func responseReturnExpression(for resultCase: EndpointResultCase) -> String {
    guard resultCases.count == 1 else {
      return resultCase.resultReturnExpression
    }

    return resultCase.valueReturnExpression
  }

  var callParameters: String {
    var parameters: [String] = []

    if generatesContentType {
      parameters.append(contentsOf: contentFields.map(\.callParameter))
    } else if hasContent {
      parameters.append("_ \(contentParameterName): \(contentType ?? "Content")")
    }

    if generatesQueryType {
      parameters.append(contentsOf: queryFields.map(\.callParameter))
    } else if hasQuery {
      parameters.append("query: \(queryType ?? "Query")")
    }

    if generatesHeaderType {
      parameters.append(contentsOf: headerFields.map(\.callParameter))
    } else if hasHeaders {
      parameters.append("headers: \(headerType ?? "Headers")\(headersDefaultExpression)")
    }

    return parameters.joined(separator: ", ")
  }

  var contentExpression: String {
    guard generatesContentType else {
      return contentParameterName
    }

    return "Content(\(contentFields.map(\.initializerArgument).joined(separator: ", ")))"
  }

  var requestContextSetup: String {
    guard hasQuery || hasHeaders || !staticHeaders.isEmpty else {
      return "let requestContext = context"
    }

    var lines = ["var requestContext = context"]

    for header in staticHeaders {
      lines.append(
        """
        requestContext = requestContext.adding(header: \(header.header))
        """
      )
    }

    if hasQuery {
      let queryExpression = generatesQueryType
        ? "Query(\(queryFields.map(\.initializerArgument).joined(separator: ", ")))"
        : "query"
      lines.append(
        """
        requestContext = requestContext.adding(
                query: UrlQueryEncoder.encode(\(queryExpression), keys: \(queryKeysExpression))
            )
        """
      )
    }

    if hasHeaders {
      let headersExpression = generatesHeaderType
        ? "Headers(\(headerFields.map(\.initializerArgument).joined(separator: ", ")))"
        : "headers"
      if generatesHeaderType {
        for field in headerFields {
          lines.append(
            """
            requestContext = requestContext.adding(
                    header: \(field.keyExpression).header(\(headersExpression).\(field.label)).erased
                )
            """
          )
        }
      } else {
        lines.append(
          """
          requestContext = requestContext.adding(
                  headers: HttpHeaderEncoder.encode(\(headersExpression))
              )
          """
        )
      }
    }

    return lines.joined(separator: "\n")
  }

  private var queryKeysExpression: String {
    guard !queryKeys.isEmpty else {
      return "[:]"
    }

    let entries = queryKeys.keys.sorted().map { key in
      "\"\(key)\": \"\(queryKeys[key]!)\""
    }
    .joined(separator: ", ")
    return "[\(entries)]"
  }

  private var headersDefaultExpression: String {
    guard generatesHeaderType,
      !headerFields.isEmpty,
      headerFields.allSatisfy({ $0.defaultValue != nil })
    else {
      return ""
    }

    return " = .init()"
  }
}

/// Field metadata used to generate endpoint contract structs from method attributes.
private struct EndpointField {
  let label: String
  let wireLabel: String
  let type: String

  var callParameter: String {
    if isOptional {
      return "\(label): \(type) = nil"
    }

    return "\(label): \(type)"
  }

  var initializerArgument: String {
    "\(label): \(label)"
  }

  private var isOptional: Bool {
    let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasSuffix("?") || (trimmed.hasPrefix("Optional<") && trimmed.hasSuffix(">"))
  }

  static func all(
    named name: String,
    in declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext
  ) -> [EndpointField] {
    var fields: [EndpointField] = []
    var seen = Set<String>()

    for element in declaration.attributes {
      guard let attribute = element.as(AttributeSyntax.self),
        attribute.attributeName.trimmedDescription == name
      else {
        continue
      }

      guard let argument = LabeledTypeAttribute(attribute) else {
        continue
      }

      guard argument.label.isSimpleSwiftIdentifier else {
        context.diagnose(
          Diagnostic(
            node: Syntax(attribute),
            message: ApiUtilsMacroDiagnostic(
              "@\(name) label '\(argument.sourceLabel)' could not be converted into a Swift identifier.",
              id: "invalid-endpoint-field-label"
            )
          )
        )
        continue
      }

      guard seen.insert(argument.label).inserted else {
        context.diagnose(
          Diagnostic(
            node: Syntax(attribute),
            message: ApiUtilsMacroDiagnostic(
              "Multiple @\(name) attributes resolve to the same label '\(argument.label)'.",
              id: "duplicate-endpoint-field-label"
            )
          )
        )
        continue
      }

      fields.append(
        EndpointField(
          label: argument.label,
          wireLabel: argument.sourceLabel,
          type: argument.type
        )
      )
    }

    return fields
  }
}

/// Field metadata used to generate endpoint header structs from method attributes.
private struct HeaderField {
  let label: String
  let keyExpression: String
  let type: String
  let defaultValue: String?

  var callParameter: String {
    if let defaultValue {
      return "\(label): \(type) = \(defaultValue)"
    }

    return "\(label): \(type)"
  }

  var initializerArgument: String {
    "\(label): \(label)"
  }

  static func all(
    in declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext
  ) -> [HeaderField] {
    var fields: [HeaderField] = []
    var seen = Set<String>()

    for element in declaration.attributes {
      guard let attribute = element.as(AttributeSyntax.self),
        attribute.attributeName.trimmedDescription == "Header"
      else {
        continue
      }

      guard let argument = HeaderAttribute(attribute) else {
        continue
      }

      guard argument.label.isSimpleSwiftIdentifier else {
        context.diagnose(
          Diagnostic(
            node: Syntax(attribute),
            message: ApiUtilsMacroDiagnostic(
              "@Header label '\(argument.sourceLabel)' could not be converted into a Swift identifier.",
              id: "invalid-endpoint-header-label"
            )
          )
        )
        continue
      }

      guard seen.insert(argument.label).inserted else {
        context.diagnose(
          Diagnostic(
            node: Syntax(attribute),
            message: ApiUtilsMacroDiagnostic(
              "Multiple @Header attributes resolve to the same label '\(argument.label)'.",
              id: "duplicate-endpoint-header-label"
            )
          )
        )
        continue
      }

      fields.append(
        HeaderField(
          label: argument.label,
          keyExpression: argument.keyExpression,
          type: argument.type,
          defaultValue: argument.defaultValue
        )
      )
    }

    return fields
  }
}

/// Nested endpoint contract type marked by endpoint contract attributes.
private struct EndpointContractType {
  let name: String
  let type: String

  static func all(markedBy attributeName: String, in declaration: some DeclGroupSyntax)
    -> [EndpointContractType]
  {
    let structs = declaration.nestedStructs.compactMap { nested -> EndpointContractType? in
      guard nested.attribute(named: attributeName) != nil else { return nil }

      return EndpointContractType(name: nested.name.text, type: nested.name.text)
    }

    let aliases = declaration.nestedTypeAliases.compactMap { alias -> EndpointContractType? in
      guard alias.attribute(named: attributeName) != nil else { return nil }

      return EndpointContractType(
        name: alias.name.text,
        type: alias.initializer.value.trimmedDescription
      )
    }

    return structs + aliases
  }
}

/// Generated endpoint result case mapped from a response or error status.
private struct EndpointResultCase {
  /// Payload decoding strategy for a generated endpoint result case.
  enum Payload {
    case data
    case void
    case decodable(String)
  }

  let caseName: String
  let statusExpression: String
  let payload: Payload

  var caseDeclaration: String {
    switch payload {
    case .void:
      return "    case \(caseName)"
    case .data:
      return "    case \(caseName)(Data)"
    case .decodable(let type):
      return "    case \(caseName)(\(type))"
    }
  }

  var resultReturnExpression: String {
    switch payload {
    case .void:
      return "return .\(caseName)"
    case .data:
      return "return .\(caseName)(response.body)"
    case .decodable(let type):
      return "return .\(caseName)(try requestContext.decode(\(type).self, from: response).body)"
    }
  }

  var valueReturnExpression: String {
    switch payload {
    case .void:
      return "return"
    case .data:
      return "return response.body"
    case .decodable(let type):
      return "return try requestContext.decode(\(type).self, from: response).body"
    }
  }

  static func all(
    in declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext
  ) -> [EndpointResultCase] {
    declaration.nestedStructs.compactMap { nested in
      resultCase(from: nested, context: context)
    }
  }

  static func defaultResponse(in declaration: some DeclGroupSyntax) -> EndpointResultCase {
    if let type = declaration.nestedTypeAlias(named: "Response") {
      return EndpointResultCase(
        caseName: "ok",
        statusExpression: ".ok",
        payload: Payload(type)
      )
    }

    if declaration.hasNestedType(named: "Response") {
      return EndpointResultCase(
        caseName: "ok",
        statusExpression: ".ok",
        payload: .decodable("Response")
      )
    }

    return EndpointResultCase(caseName: "ok", statusExpression: ".ok", payload: .void)
  }

  static func hasDefaultResponse(in declaration: some DeclGroupSyntax) -> Bool {
    declaration.nestedTypeAlias(named: "Response") != nil
      || declaration.nestedStructs.contains { nested in
        nested.name.text == "Response" && nested.attribute(named: "Response") == nil
      }
  }

  static func diagnoseDuplicates(
    _ resultCases: [EndpointResultCase],
    in declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext
  ) {
    var seen = Set<String>()
    for resultCase in resultCases {
      guard seen.insert(resultCase.caseName).inserted == false else {
        continue
      }

      context.diagnose(
        Diagnostic(
          node: Syntax(declaration),
          message: ApiUtilsMacroDiagnostic(
            "Multiple endpoint result cases resolve to '\(resultCase.caseName)'.",
            id: "duplicate-endpoint-result-case"
          )
        )
      )
    }
  }

  private static func resultCase(
    from declaration: StructDeclSyntax,
    context: some MacroExpansionContext
  ) -> EndpointResultCase? {
    guard let attribute = declaration.attribute(named: "Response"),
      let status = StatusAttribute(attribute)
    else {
      return nil
    }

    if status.hasNoBody,
      declaration.hasStoredProperties
    {
      context.diagnose(
        Diagnostic(
          node: Syntax(declaration),
          message: ApiUtilsMacroDiagnostic(
            "@Status(\(status.statusExpression)) cannot declare stored properties because the status has no response body.",
            id: "no-body-response-has-stored-properties"
          )
        )
      )
    }

    return EndpointResultCase(
      caseName: status.caseName,
      statusExpression: status.statusExpression,
      payload: Payload(status: status, type: declaration.name.text)
    )
  }
}

private extension EndpointResultCase.Payload {
  init(status: StatusAttribute, type: String) {
    if status.hasNoBody {
      self = .void
      return
    }

    self = .decodable(type)
  }

  init(_ type: String) {
    switch type {
    case "Data":
      self = .data
    case "Void", "()":
      self = .void
    default:
      self = .decodable(type)
    }
  }
}

private struct QueryParameter {
  let name: String
  let localName: String

  init?(_ parameter: FunctionParameterSyntax) {
    guard let attribute = parameter.attribute(named: "Query") else {
      return nil
    }

    name = RouteAttribute(attribute).path ?? parameter.localName
    localName = parameter.localName
  }
}

private struct ContentParameter {
  let localName: String

  init?(_ parameter: FunctionParameterSyntax) {
    guard parameter.attribute(named: "Content") != nil else {
      return nil
    }

    localName = parameter.localName
  }
}

private extension HTTPMethodBody.Method {
  var attributeName: String {
    switch self {
    case .get:
      return "Get"
    case .post:
      return "Post"
    case .put:
      return "Put"
    case .patch:
      return "Patch"
    case .delete:
      return "Delete"
    }
  }
}

private extension DeclGroupSyntax {
  var nestedStructs: [StructDeclSyntax] {
    memberBlock.members.compactMap { member in
      member.decl.as(StructDeclSyntax.self)
    }
  }

  var nestedTypeAliases: [TypeAliasDeclSyntax] {
    memberBlock.members.compactMap { member in
      member.decl.as(TypeAliasDeclSyntax.self)
    }
  }

  func hasNestedType(named name: String) -> Bool {
    nestedTypeAlias(named: name) != nil
      || memberBlock.members.contains { member in
        if let declaration = member.decl.as(StructDeclSyntax.self) {
          return declaration.name.text == name
        }
        if let declaration = member.decl.as(EnumDeclSyntax.self) {
          return declaration.name.text == name
        }
        if let declaration = member.decl.as(ClassDeclSyntax.self) {
          return declaration.name.text == name
        }
        return false
      }
  }

  func nestedTypeAlias(named name: String) -> String? {
    memberBlock.members.compactMap { member -> String? in
      guard let declaration = member.decl.as(TypeAliasDeclSyntax.self),
        declaration.name.text == name
      else {
        return nil
      }

      return declaration.initializer.value.trimmedDescription
    }
    .first
  }

  func nestedKeys(for typeName: String) -> [String: String] {
    guard let query = nestedStructs.first(where: { declaration in
      declaration.name.text == typeName
    }) else {
      return [:]
    }

    return query.memberBlock.members.reduce(into: [:]) { result, member in
      guard let variable = member.decl.as(VariableDeclSyntax.self),
        let key = variable.attribute(named: "Key")?.firstStringArgument,
        let binding = variable.bindings.first,
        let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
      else {
        return
      }

      result[pattern.identifier.text] = key
    }
  }
}

private extension StructDeclSyntax {
  var hasStoredProperties: Bool {
    memberBlock.members.contains { member in
      guard let variable = member.decl.as(VariableDeclSyntax.self),
        variable.bindings.count == 1,
        let binding = variable.bindings.first
      else {
        return false
      }

      return binding.accessorBlock == nil
    }
  }
}

private extension AttributeSyntax {
  var firstStringArgument: String? {
    AttributeArgument.firstStringLiteral(in: self)
  }
}

private extension TypeAliasDeclSyntax {
  func attribute(named name: String) -> AttributeSyntax? {
    attributes.lazy.compactMap { element in
      element.as(AttributeSyntax.self)
    }
    .first { attribute in
      attribute.attributeName.trimmedDescription == name
    }
  }
}

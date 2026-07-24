# Kiosk Publication TODO

## Premise

Kiosk is a lean Swift package for declaring discoverable REST clients as nested route trees. `HttpContext` is the request configuration driver, and macros generate the repetitive route, endpoint, request, response, serialization, and validation code.

## Public Macro Inventory

- API tree: `@Api`, `@Path`, `@Route`, `@Param`.
- HTTP contracts: `@Get`, `@Post`, `@Put`, `@Patch`, `@Delete`, `@Query`, `@Header`, `@Content`, `@Accept`, `@Field(_:_: )`, `@Part`, `@Response`, `@Wrap`, `@Unwrap`.
- Serialization: `@Serializable`, `@Field(_:)`, `@Format`, `@Default`.
- Validation: `@Validatable`, `@Required`, `@NonEmpty`, `@Range`, `@Pattern`, `@Past`, `@Future`, `@Validate`.
- Pre-release decision: dictionary and value helpers currently exist in source, but the README does not document them as part of Kiosk's v0.1 public promise.

## Runtime Inventory

- Request configuration: `HttpContext`, `RequestContext`, `WrapperKey`, `WrapperRegistry`, `HttpWrapper`, `HttpOptions`.
- HTTP primitives: `HTTPMethod`, `HTTPHeaderFieldName`, `HttpHeader`, `HTTPContentType`, `HTTPStatusCode`, `HttpRequest`, `HttpResponse`.
- URL and encoding: `UrlBuilder`, `UrlQueryEncoder`, `HttpHeaderEncoder`, `HTTPContentEncoder`, `SerializationContext`.
- Local models: `Serializable`, `Validatable`, `ValidationContext`.
- Experimental: `WsContext` and `WsOptions` are present but not documented as v0.1 public claims.

## Claim To Test Map

- Discoverable nested route client surface: `testPathMacrosBuildNestedContextWithKioskImport`, `testApiMacroBuildsPathTreeLikeRootApiNamespace`, `testUnlabeledPathConvertsStructNamesToURLSegments`.
- Scoped `HttpContext` configuration: `testContentMetadataInheritsAndOverridesAcrossPathTree`, `testAcceptHeaderReachesFinalURLRequest`, `testHttpContextCanConfigureWrappersWithoutExternalProducts`, `testApiProxyMethodsRebuildChildContexts`.
- REST endpoint contract generation: `testGetMacroBuildsRequestWithQueryParameters`, `testPostMacroBuildsRequestContent`, `testEndpointStructMacrosBuildComprehensiveAPI`, `testEndpointStructMacrosReturnDeclaredResults`.
- Wrapper behavior: `testWrapAndUnwrapMacrosScopeRegisteredWrappers`, `testWrappersRunInOrderAndCanMutateGeneratedRequests`, `testGeneratedEndpointsAndHandwrittenContextUseSameWrapperPipeline`, `testApiProxyMethodsCanRegisterMiddleware`, `testRouteAndEndpointProxyMethodsCanUpdateRequests`.
- Single import for model macros: `testSingleImportExposesSerializationMacros`, `testSingleImportExposesValidationMacros`.

## Pre-release Checklist

- [x] Run `swift package dump-package`.
- [x] Run `swift test`.
- [x] Check package builds from a clean copy without local path dependencies.
- [ ] Decide whether dictionary/value helper macros stay public, become internal, or move to another package.
- [ ] Create GitHub repo `ozerov-studio/kiosk-swift`.
- [ ] Push the package source.
- [ ] Tag `0.1.0`.
- [ ] Submit `https://github.com/ozerov-studio/kiosk-swift` to Swift Package Index.
- [ ] After SPI indexes the package, review build matrix and documentation rendering.

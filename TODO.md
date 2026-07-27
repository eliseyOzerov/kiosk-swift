# Kiosk Publication TODO

## Premise

Kiosk is a lean Swift package for declaring discoverable REST clients as nested route trees. `HttpContext` is the request configuration driver, and macros generate the repetitive route, endpoint, request, response, and wire code.

## Public Macro Inventory

- API tree: `@Api`, `@Path`, `@Param`. `@Api` can seed root URL defaults with the same `UrlBuilder` API used by generated initializers.
- HTTP contracts: `@Get`, `@Post`, `@Put`, `@Patch`, `@Delete`, `@Query`, `@Header`, `@Content`, `@Part`, `@Status`, `@Wrap`, `@Unwrap`.
- Wire: `@Wire`, `@Codec`, `@Rename`, `@Field(_:)`, `@Format`, `@Default`.
- Kept temporarily for field naming: `@Key`.
- Deferred ideas: validation macros such as `@Validatable`, `@Required`, `@NonEmpty`, `@Range`, `@Pattern`, `@Past`, `@Future`, and `@Validate`.
- Removed before v0.1: `@Route`, `@Accept`, and dictionary/value helper macros other than `@Key`.

## Runtime Inventory

- Request configuration: `HttpContext`, `RequestContext`, `WrapperKey`, `WrapperRegistry`, `HttpWrapper`, `HttpOptions`.
- HTTP primitives: `HTTPMethod`, `HttpHeaderKey`, `HttpHeader`, `AnyHttpHeader`, `HTTPContentType`, `HTTPStatusCode`, `HttpRequest`, `HttpResponse`.
- URL and encoding: `UrlBuilder`, `UrlQueryEncoder`, `HttpHeaderEncoder`, `HTTPContentEncoder`, `WireSpec`.
- Local models: `WireCodable`, `WireSpec`.
- Experimental: `WsContext` and `WsOptions` are present but not documented as v0.1 public claims.

## Claim To Test Map

- Discoverable nested route client surface: `testPathMacrosBuildNestedContextWithKioskImport`, `testApiMacroBuildsPathTreeLikeRootApiNamespace`, `testUnlabeledPathConvertsStructNamesToURLSegments`.
- Scoped `HttpContext` configuration: `testApiMacroConfigurationBuildsDefaultContext`, `testContentMetadataInheritsAndOverridesAcrossPathTree`, `testAcceptHeaderReachesFinalURLRequest`, `testHttpContextCanConfigureWrappersWithoutExternalProducts`, `testApiProxyMethodsRebuildChildContexts`.
- REST endpoint contract generation: `testGetMacroBuildsRequestWithQueryParameters`, `testPostMacroBuildsRequestContent`, `testEndpointStructMacrosBuildComprehensiveAPI`, `testEndpointStructMacrosReturnDeclaredResults`.
- Wrapper behavior: `testWrapAndUnwrapMacrosScopeRegisteredWrappers`, `testWrappersRunInOrderAndCanMutateGeneratedRequests`, `testGeneratedEndpointsAndHandwrittenContextUseSameWrapperPipeline`, `testApiProxyMethodsCanRegisterMiddleware`, `testRouteAndEndpointProxyMethodsCanUpdateRequests`.
- Single import and scoped model wire: `testSingleImportExposesWireMacros`, `testWireSpecDrivesLocalModelCoding`, `testApiWireSpecDrivesGeneratedJSONContent`, `testScopedWireMacrosDriveGeneratedJSONContent`.

## Pre-release Checklist

- [x] Run `swift package dump-package`.
- [x] Run `swift test`.
- [x] Check package builds from a clean copy without local path dependencies.
- [x] Remove dictionary/value helper macros from the v0.1 public surface, keeping `@Key` temporarily for field naming.
- [x] Add `AGENTS.md` as a compact implementation guide for coding agents.
- [x] Add a `Kiosk.docc` catalog and `.spi.yml` documentation target for Swift Package Index hosted docs.
- [ ] Push the package source.
- [ ] Tag the next release.
- [ ] Submit `https://github.com/eliseyOzerov/kiosk-swift` to Swift Package Index.
- [ ] After SPI indexes the package, review build matrix and documentation rendering.

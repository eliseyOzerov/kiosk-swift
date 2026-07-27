# Agent Guide

Kiosk is a Swift package for discoverable REST clients with scoped request configuration.

Before editing Kiosk client code:

- Read `Sources/Kiosk/Kiosk.docc/BuildingRequests.md`.
- Model APIs as nested `@Api`, `@Path`, and method structs.
- Prefer endpoint-local `Content`, `Response`, and `@Status` models.
- Configure headers, middleware, and wire policy through macros or generated context proxy methods.
- Keep validation out of Kiosk v0.1 code and docs except as a future idea.
- Add or update tests that assert generated `URLRequest` shape when request behavior changes.

Reference map:

- Package overview: `Sources/Kiosk/Kiosk.docc/Kiosk.md`
- Request construction: `Sources/Kiosk/Kiosk.docc/BuildingRequests.md`
- Route trees: `Sources/Kiosk/Kiosk.docc/RouteTrees.md`
- Parameters and content: `Sources/Kiosk/Kiosk.docc/RequestParameters.md`
- Headers: `Sources/Kiosk/Kiosk.docc/Headers.md`
- Status responses: `Sources/Kiosk/Kiosk.docc/StatusResponses.md`
- Middleware: `Sources/Kiosk/Kiosk.docc/Middleware.md`
- Wire DTOs: `Sources/Kiosk/Kiosk.docc/WireModels.md`
- Testing expectations: `Sources/Kiosk/Kiosk.docc/Testing.md`

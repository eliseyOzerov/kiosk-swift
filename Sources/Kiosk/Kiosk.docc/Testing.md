# Testing

Keep tests focused on the generated request surface and runtime behavior.

## Request Shape

When changing macros or request configuration, add tests that assert the final `URLRequest` shape:

- HTTP method
- URL path
- query items
- headers
- content type
- encoded body
- response decoding
- scoped status errors

Prefer public `import Kiosk` tests when the claim is part of the package surface.

## Scope Behavior

For inherited configuration, test at least one parent scope and one nested override. Useful examples include headers, content type, wire policy, wrapper activation, and status models.

## Wire Models

Wire tests should prove both local DTO coding and generated endpoint request coding when a README or DocC claim depends on that behavior.

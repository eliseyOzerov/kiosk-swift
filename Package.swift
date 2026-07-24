// swift-tools-version: 6.1

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "Kiosk",
  platforms: [.iOS(.v18), .macOS(.v14), .tvOS(.v17), .visionOS(.v1)],
  products: [.library(name: "Kiosk", targets: ["Kiosk"])],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.0"),
  ],
  targets: [
    .macro(
      name: "KioskMacros",
      dependencies: [
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      ],
      path: "Sources/KioskMacros"
    ),
    .target(
      name: "Kiosk",
      dependencies: [
        "KioskMacros",
      ],
      exclude: ["DESIGN.md"]
    ),
    .testTarget(name: "KioskTests", dependencies: ["Kiosk"]),
  ]
)

// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HelloMCP",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "hellomcp", targets: ["HelloMCP"])],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "HelloMCP",
            dependencies: [.product(name: "MCP", package: "swift-sdk"),
                           .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
            ]
        )
    ]
)

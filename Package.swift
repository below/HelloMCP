// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HelloMCP",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "HelloMCPCore", targets: ["HelloMCPCore"]),
        .executable(name: "hellomcp", targets: ["HelloMCP"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.1")
    ],
    targets: [
        .target(
            name: "HelloMCPCore",
            dependencies: [.product(name: "MCP", package: "swift-sdk")]
        ),
        .executableTarget(
            name: "HelloMCP",
            dependencies: [
                "HelloMCPCore",
                .product(name: "MCP", package: "swift-sdk")
            ]
        ),
        .testTarget(
            name: "HelloMCPCoreTests",
            dependencies: ["HelloMCPCore"]
        )
    ]
)

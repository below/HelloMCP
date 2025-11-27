import Foundation
import MCP
import FoundationModels
import ServiceLifecycle
import Logging

let logger = Logger(label: "com.example.mcp-server")

// Create the MCP server
let server = Server(
    name: "HelloMCP",
    version: "1.0.0",
    capabilities: .init(
        prompts: .init(listChanged: true),
        resources: .init(subscribe: true, listChanged: true),
        tools: .init(listChanged: true)
    )
)

// MARK: Tools
await server.withMethodHandler(ListTools.self) { _ in
    let tools = [
        Tool(
            name: "applechat",
            description: "Execute a string using Apple Foundation Models",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "instructions": .object([
                        "description": .string("Instructions to model"),
                        "type": .string("string")
                    ]),
                    "prompt": .object([
                    "description": .string("Instructions to model"),
                    "type": .string("string")
                    ])
                ])
            ])
        ),
        Tool(
            name: "weather",
            description: "Get current weather for a location",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "location": .object([
                        "description":                             .string("City name or coordinates"),
                        "type": .string("string"),
                        "units": .string("Units of measurement, e.g., metric, imperial")
                    ])
                    
                ])
            ])
        ),
        Tool(
            name: "calculator",
            description: "Perform calculations",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "expression": .object([
                        "type": .string("string"),
                        "description": .string("Mathematical expression to evaluate")
                    ])
                ])
            ])
        )
    ]
    return .init(tools: tools)
}

await server.withMethodHandler(CallTool.self) { params in
    switch params.name {
    case "applechat":
        let instructions: String? = params.arguments?["instructions"]?.stringValue
        let prompt = params.arguments?["prompt"]?.stringValue ?? ""
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel( guardrails: .permissiveContentTransformations)
            guard model.availability == .available else {
                return .init(content: [.text("Model not available")], isError: true)
            }
            let session = LanguageModelSession(model: model, instructions: instructions)
            do {
                let response = try await session.respond(to: prompt)
                return .init(content: [.text(response.content)], isError: false)
            } catch {
                return .init(
                    content: [.text("Unable to respond")],
                    isError: true
                )
            }
        } else {
            return .init(
                content: [.text("Tool Server is not on macOS 26")],
                isError: true
            )
        }

    case "weather":
        let location = params.arguments?["location"]?.stringValue ?? "Unknown"
        let units = params.arguments?["units"]?.stringValue ?? "metric"
        let weatherData = getWeatherData(location: location, units: units) // Your implementation
        return .init(
            content: [.text("Weather for \(location): \(weatherData.temperature)°, \(weatherData.conditions)")],
            isError: false
        )

    case "calculator":
        if let expression = params.arguments?["expression"]?.stringValue {
            let result = evaluateExpression(expression) // Your implementation
            return .init(content: [.text("\(result)")], isError: false)
        } else {
            return .init(content: [.text("Missing expression parameter")], isError: true)
        }

    default:
        return .init(content: [.text("Unknown tool")], isError: true)
    }
}

// MARK: Resource

// Register a resource list handler
await server.withMethodHandler(ListResources.self) { params in
    let resources = [
        Resource(
            name: "Knowledge Base Articles",
            uri: "resource://knowledge-base/articles",
            description: "Collection of support articles and documentation"
        ),
        Resource(
            name: "System Status",
            uri: "resource://system/status",
            description: "Current system operational status"
        )
    ]
    return .init(resources: resources, nextCursor: nil)
}

// Register a resource read handler
await server.withMethodHandler(ReadResource.self) { params in
    switch params.uri {
    case "resource://knowledge-base/articles":
        return .init(contents: [Resource.Content.text("# Knowledge Base\n\nThis is the content of the knowledge base...", uri: params.uri)])

    case "resource://system/status":
        let versionString = ProcessInfo.processInfo.operatingSystemVersionString
        var appleIntelligenceAvailable = false
        var modelAvailable = false
        
        if #available(macOS 26.0, *) {
            appleIntelligenceAvailable = true
            let model = SystemLanguageModel( guardrails: .permissiveContentTransformations)
            if model.availability == .available {
                modelAvailable = true
            }
        }

        let statusJson = """
            {
                "osVersion": "\(versionString)",
                "Apple Intelligence available": "\(appleIntelligenceAvailable)",
                "Foundation Model available": "\(modelAvailable)",
                "lastUpdated": "\(Date().description)"
            }
            """
        return .init(contents: [Resource.Content.text(statusJson, uri: params.uri, mimeType: "application/json")])

    default:
        throw MCPError.invalidParams("Unknown resource URI: \(params.uri)")
    }
}

// Create MCP service and other services
let transport = StdioTransport(logger: logger)
let mcpService = MCPService(server: server, transport: transport)

// Create service group with signal handling
let serviceGroup = ServiceGroup(
    services: [mcpService],
    gracefulShutdownSignals: [.sigterm, .sigint],
    logger: logger
)

// Run the service group - this blocks until shutdown
try await serviceGroup.run()

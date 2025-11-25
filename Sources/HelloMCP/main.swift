import MCP
import FoundationModels
import Foundation

// Create a server with given capabilities
let server = Server(
    name: "MyModelServer",
    version: "1.0.0",
    capabilities: .init(
        prompts: .init(listChanged: true),
        resources: .init(subscribe: true, listChanged: true),
        tools: .init(listChanged: true)
    )
)

// Create transport and start server
let transport = StdioTransport()
try await server.start(transport: transport)

// Now register handlers for the capabilities you've enabled

// Register a tool list handler
await server.withMethodHandler(ListTools.self) { _ in
    let tools = [
        Tool(
            name: "weather",
            description: "Get current weather for a location",
            inputSchema: .object([
                "properties": .object([
                    "location": .string("City name or coordinates"),
                    "units": .string("Units of measurement, e.g., metric, imperial")
                ])
            ])
        ),
        Tool(
            name: "calculator",
            description: "Perform calculations",
            inputSchema: .object([
                "properties": .object([
                    "expression": .string("Mathematical expression to evaluate")
                ])
            ])
        )
    ]
    return .init(tools: tools)
}

// Register a tool call handler
await server.withMethodHandler(CallTool.self) { params in
    switch params.name {
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

// MARK: -- Helper functions

func evaluateExpression(_ expression: String) -> String {
    return "42"
}

func getWeatherData(location: String, units: String) -> (temperature: String, conditions: String) {
    return (temperature: "22", conditions: "Sunny")
}

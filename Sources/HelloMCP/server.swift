import MCP
import ServiceLifecycle
import Logging

struct MCPService: Service {
    let server: Server
    let transport: Transport

    init(server: Server, transport: Transport) {
        self.server = server
        self.transport = transport
    }

    func run() async throws {
        // Start the server
        try await server.start(transport: transport)

        // Keep running until external cancellation
        try await Task.sleep(for: .seconds(60 * 60 * 24 * 365 * 100))  // Effectively forever
    }

    func shutdown() async throws {
        // Gracefully shutdown the server
        await server.stop()
    }
}

// MARK: -- Helper functions

func evaluateExpression(_ expression: String) -> String {
    return "42"
}

func getWeatherData(location: String, units: String) -> (temperature: String, conditions: String) {
    return (temperature: "22", conditions: "Sunny")
}

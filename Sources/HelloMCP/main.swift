import MCP
import FoundationModels

// Create a server with given capabilities
let server = Server(
    name: "HelloMCP",
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
            name: "applechat",
            description: "Get a reply from Apple Foundation Models",
            inputSchema: .object([
                "properties": .object([
                    "instructions": .string("Instructions to model"),
                    "prompt": .string("Prompt")
                ])
            ])
        ),
    ]
    return .init(tools: tools)
}

// Register a tool call handler
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
                    isError: false
                )
            }
        } else {
            return .init(
                content: [.text("Tool Server is not on macOS 26")],
                isError: false
            )
        }
        
    default:
        return .init(content: [.text("Unknown tool")], isError: true)
    }
}

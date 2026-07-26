import Foundation
import HelloMCPCore
import Logging
import MCP

let logger = Logger(label: "com.example.hellomcp")
let runner = FoundationModelRunner()
let diagnostics = RuntimeDiagnostics()

let server = Server(
    name: "HelloMCP",
    version: helloMCPServerVersion,
    title: "HelloMCP",
    instructions: helloMCPInstructions,
    capabilities: .init(
        resources: .init(subscribe: false, listChanged: false),
        tools: .init(listChanged: false)
    )
)

await server.withMethodHandler(ListTools.self) { _ in
    .init(tools: [runFoundationModelPromptTool()])
}

await server.withMethodHandler(CallTool.self) { params in
    guard params.name == runFoundationModelPromptToolName else {
        let response = PromptToolResponse(
            response: nil,
            sessionId: nil,
            stateless: true,
            durationMs: 0,
            modelAvailable: false,
            availability: "unknown",
            error: .init(code: "unknown_tool", message: "Unknown tool: \(params.name)")
        )
        return try .init(
            content: [.text(text: response.error?.message ?? "Unknown tool", annotations: nil, _meta: nil)],
            structuredContent: response,
            isError: true
        )
    }

    do {
        let request = try PromptToolRequest.parse(arguments: params.arguments)
        let response = await runner.respond(to: request)
        if let error = response.error {
            await diagnostics.record(error: error)
        } else {
            await diagnostics.clearError()
        }

        return try .init(
            content: [.text(text: response.response ?? response.error?.message ?? "No response", annotations: nil, _meta: nil)],
            structuredContent: response,
            isError: response.error != nil
        )
    } catch let error as PromptToolValidationError {
        let toolError = PromptToolError(code: error.code, message: error.message)
        await diagnostics.record(error: toolError)
        let response = PromptToolResponse(
            response: nil,
            sessionId: params.arguments?["sessionId"]?.stringValue,
            stateless: params.arguments?["sessionId"]?.stringValue == nil,
            durationMs: 0,
            modelAvailable: false,
            availability: "notChecked",
            error: toolError
        )
        return try .init(
            content: [.text(text: error.message, annotations: nil, _meta: nil)],
            structuredContent: response,
            isError: true
        )
    } catch {
        let toolError = PromptToolError(code: "invalid_arguments", message: String(describing: error))
        await diagnostics.record(error: toolError)
        let response = PromptToolResponse(
            response: nil,
            sessionId: params.arguments?["sessionId"]?.stringValue,
            stateless: params.arguments?["sessionId"]?.stringValue == nil,
            durationMs: 0,
            modelAvailable: false,
            availability: "notChecked",
            error: toolError
        )
        return try .init(
            content: [.text(text: toolError.message, annotations: nil, _meta: nil)],
            structuredContent: response,
            isError: true
        )
    }
}

await server.withMethodHandler(ListResources.self) { _ in
    let resources = [
        Resource(
            name: "System Status",
            uri: systemStatusResourceURI,
            description: "Current HelloMCP and Apple Foundation Models availability status",
            mimeType: "application/json"
        )
    ]
    return .init(resources: resources, nextCursor: nil)
}

await server.withMethodHandler(ReadResource.self) { params in
    guard params.uri == systemStatusResourceURI else {
        throw MCPError.invalidParams("Unknown resource URI: \(params.uri)")
    }

    let lastError = await diagnostics.currentLastError()
    let status = await runner.status(lastError: lastError)
    let json = try jsonString(status)
    return .init(contents: [
        Resource.Content.text(json, uri: params.uri, mimeType: "application/json")
    ])
}

let transport = StdioTransport(logger: logger)
try await server.start(transport: transport)
try await Task.sleep(for: .seconds(60 * 60 * 24 * 365 * 100))

import Foundation
import FoundationModels
import MCP

public let helloMCPServerVersion = "2.0.0"
public let runFoundationModelPromptToolName = "run_foundation_model_prompt"
public let systemStatusResourceURI = "resource://system/status"

public let helloMCPInstructions = """
Use this server only to evaluate prompts with Apple's on-device Foundation Models. Do not use it for file edits, shell commands, coding answers, or unrelated general reasoning. Calls are stateless unless the caller provides a sessionId.
"""

public struct PromptToolRequest: Sendable, Equatable {
    public let prompt: String
    public let instructions: String?
    public let sessionId: String?
    public let resetSession: Bool
    public let maximumResponseTokens: Int?
    public let temperature: Double?

    public init(
        prompt: String,
        instructions: String? = nil,
        sessionId: String? = nil,
        resetSession: Bool = false,
        maximumResponseTokens: Int? = nil,
        temperature: Double? = nil
    ) {
        self.prompt = prompt
        self.instructions = instructions
        self.sessionId = sessionId
        self.resetSession = resetSession
        self.maximumResponseTokens = maximumResponseTokens
        self.temperature = temperature
    }

    public static func parse(arguments: [String: Value]?) throws -> PromptToolRequest {
        let arguments = arguments ?? [:]
        guard let prompt = arguments["prompt"]?.stringValue,
              !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PromptToolValidationError(code: "missing_prompt", message: "Missing required string argument: prompt")
        }

        let instructions = arguments["instructions"]?.stringValue
        let sessionId = arguments["sessionId"]?.stringValue
        let resetSession = arguments["resetSession"]?.boolValue ?? false
        let maximumResponseTokens = arguments["maximumResponseTokens"]?.intValue
        let temperature = arguments["temperature"]?.doubleValue ?? arguments["temperature"]?.intValue.map(Double.init)

        if let sessionId {
            try validateSessionId(sessionId)
        }

        if let maximumResponseTokens, maximumResponseTokens <= 0 {
            throw PromptToolValidationError(
                code: "invalid_maximum_response_tokens",
                message: "maximumResponseTokens must be a positive integer"
            )
        }

        if let temperature, !(0...1).contains(temperature) {
            throw PromptToolValidationError(
                code: "invalid_temperature",
                message: "temperature must be between 0 and 1, inclusive"
            )
        }

        return PromptToolRequest(
            prompt: prompt,
            instructions: instructions,
            sessionId: sessionId,
            resetSession: resetSession,
            maximumResponseTokens: maximumResponseTokens,
            temperature: temperature
        )
    }

    private static func validateSessionId(_ sessionId: String) throws {
        guard (1...128).contains(sessionId.count) else {
            throw PromptToolValidationError(
                code: "invalid_session_id",
                message: "sessionId must contain 1 to 128 characters"
            )
        }

        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-." )
        guard sessionId.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw PromptToolValidationError(
                code: "invalid_session_id",
                message: "sessionId may contain only ASCII letters, digits, underscore, hyphen, and dot"
            )
        }
    }
}

public struct PromptToolValidationError: Error, Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct PromptToolError: Codable, Hashable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct PromptToolResponse: Codable, Hashable, Sendable {
    public let response: String?
    public let sessionId: String?
    public let stateless: Bool
    public let durationMs: Int
    public let modelAvailable: Bool
    public let availability: String
    public let warnings: [String]
    public let error: PromptToolError?

    public init(
        response: String?,
        sessionId: String?,
        stateless: Bool,
        durationMs: Int,
        modelAvailable: Bool,
        availability: String,
        warnings: [String] = [],
        error: PromptToolError? = nil
    ) {
        self.response = response
        self.sessionId = sessionId
        self.stateless = stateless
        self.durationMs = durationMs
        self.modelAvailable = modelAvailable
        self.availability = availability
        self.warnings = warnings
        self.error = error
    }
}

public struct SystemStatus: Codable, Hashable, Sendable {
    public let serverVersion: String
    public let osVersion: String
    public let toolName: String
    public let foundationModelsAvailable: Bool
    public let availability: String
    public let activeSessionCount: Int
    public let lastError: PromptToolError?
    public let lastUpdated: String
}

public actor RuntimeDiagnostics {
    private var lastError: PromptToolError?

    public init() {}

    public func record(error: PromptToolError) {
        lastError = error
    }

    public func clearError() {
        lastError = nil
    }

    public func currentLastError() -> PromptToolError? {
        lastError
    }
}

public actor FoundationModelRunner {
    private var sessions: [String: Any] = [:]

    public init() {}

    public func respond(to request: PromptToolRequest) async -> PromptToolResponse {
        let start = ContinuousClock.now
        guard #available(macOS 26.0, *) else {
            return makeErrorResponse(
                code: "unsupported_os",
                message: "FoundationModels requires macOS 26.0 or newer",
                request: request,
                start: start,
                availability: "unsupportedOS"
            )
        }

        return await respondOnSupportedOS(to: request, start: start)
    }

    public func activeSessionCount() -> Int {
        sessions.count
    }

    public func status(lastError: PromptToolError?) async -> SystemStatus {
        let availability = foundationModelAvailability()
        return SystemStatus(
            serverVersion: helloMCPServerVersion,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            toolName: runFoundationModelPromptToolName,
            foundationModelsAvailable: availability.available,
            availability: availability.description,
            activeSessionCount: sessions.count,
            lastError: lastError,
            lastUpdated: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func makeErrorResponse(
        code: String,
        message: String,
        request: PromptToolRequest,
        start: ContinuousClock.Instant,
        availability: String,
        modelAvailable: Bool = false
    ) -> PromptToolResponse {
        PromptToolResponse(
            response: nil,
            sessionId: request.sessionId,
            stateless: request.sessionId == nil,
            durationMs: elapsedMilliseconds(since: start),
            modelAvailable: modelAvailable,
            availability: availability,
            error: PromptToolError(code: code, message: message)
        )
    }

    private func elapsedMilliseconds(since start: ContinuousClock.Instant) -> Int {
        let elapsed = start.duration(to: ContinuousClock.now)
        let components = elapsed.components
        return Int(components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000)
    }

    private func foundationModelAvailability() -> (available: Bool, description: String) {
        guard #available(macOS 26.0, *) else {
            return (false, "unsupportedOS")
        }

        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let description = String(describing: model.availability)
        return (model.availability == .available, description)
    }
}

@available(macOS 26.0, *)
private extension FoundationModelRunner {
    func respondOnSupportedOS(to request: PromptToolRequest, start: ContinuousClock.Instant) async -> PromptToolResponse {
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let availability = String(describing: model.availability)
        guard model.availability == .available else {
            return makeErrorResponse(
                code: "model_unavailable",
                message: "Foundation model is not available: \(availability)",
                request: request,
                start: start,
                availability: availability
            )
        }

        let session: LanguageModelSession
        if let sessionId = request.sessionId {
            if request.resetSession || sessions[sessionId] == nil {
                sessions[sessionId] = LanguageModelSession(model: model, instructions: request.instructions)
            }

            if let storedSession = sessions[sessionId] as? LanguageModelSession {
                session = storedSession
            } else {
                let newSession = LanguageModelSession(model: model, instructions: request.instructions)
                sessions[sessionId] = newSession
                session = newSession
            }
        } else {
            session = LanguageModelSession(model: model, instructions: request.instructions)
        }

        do {
            let options = GenerationOptions(
                sampling: nil,
                temperature: request.temperature,
                maximumResponseTokens: request.maximumResponseTokens
            )
            let response = try await session.respond(to: request.prompt, options: options)
            return PromptToolResponse(
                response: response.content,
                sessionId: request.sessionId,
                stateless: request.sessionId == nil,
                durationMs: elapsedMilliseconds(since: start),
                modelAvailable: true,
                availability: availability,
                warnings: warnings(for: request)
            )
        } catch {
            return makeErrorResponse(
                code: "generation_failed",
                message: String(describing: error),
                request: request,
                start: start,
                availability: availability,
                modelAvailable: true
            )
        }
    }

    func warnings(for request: PromptToolRequest) -> [String] {
        var warnings: [String] = []
        if request.maximumResponseTokens != nil {
            warnings.append("maximumResponseTokens can truncate responses before they naturally finish.")
        }
        return warnings
    }
}

public func runFoundationModelPromptTool(inputSchema: Value = promptToolInputSchema(), outputSchema: Value = promptToolOutputSchema()) -> MCP.Tool {
    MCP.Tool(
        name: runFoundationModelPromptToolName,
        title: "Run Foundation Model Prompt",
        description: "Evaluate a prompt with Apple's on-device Foundation Models. Use for local prompt testing and prompt iteration only.",
        inputSchema: inputSchema,
        annotations: Tool.Annotations(
            title: "Run Foundation Model Prompt",
            readOnlyHint: true,
            destructiveHint: false,
            idempotentHint: false,
            openWorldHint: false
        ),
        outputSchema: outputSchema
    )
}

public func promptToolInputSchema() -> Value {
    .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([.string("prompt")]),
        "properties": .object([
            "prompt": .object([
                "type": .string("string"),
                "description": .string("Prompt to evaluate with Apple Foundation Models"),
                "minLength": .int(1)
            ]),
            "instructions": .object([
                "type": .string("string"),
                "description": .string("Optional model instructions for this session or stateless call")
            ]),
            "sessionId": .object([
                "type": .string("string"),
                "description": .string("Optional explicit session identifier for multi-turn context"),
                "minLength": .int(1),
                "maxLength": .int(128),
                "pattern": .string("^[A-Za-z0-9_.-]+$")
            ]),
            "resetSession": .object([
                "type": .string("boolean"),
                "description": .string("When true, recreate the named session before responding")
            ]),
            "maximumResponseTokens": .object([
                "type": .string("integer"),
                "description": .string("Optional maximum response token count. Must be positive."),
                "minimum": .int(1)
            ]),
            "temperature": .object([
                "type": .string("number"),
                "description": .string("Optional sampling temperature from 0 to 1. Omit to use the system default."),
                "minimum": .int(0),
                "maximum": .int(1)
            ])
        ])
    ])
}

public func promptToolOutputSchema() -> Value {
    .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([
            .string("stateless"),
            .string("durationMs"),
            .string("modelAvailable"),
            .string("availability"),
            .string("warnings")
        ]),
        "properties": .object([
            "response": .object(["type": .array([.string("string"), .string("null")])]),
            "sessionId": .object(["type": .array([.string("string"), .string("null")])]),
            "stateless": .object(["type": .string("boolean")]),
            "durationMs": .object(["type": .string("integer")]),
            "modelAvailable": .object(["type": .string("boolean")]),
            "availability": .object(["type": .string("string")]),
            "warnings": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
            "error": .object([
                "type": .array([.string("object"), .string("null")]),
                "properties": .object([
                    "code": .object(["type": .string("string")]),
                    "message": .object(["type": .string("string")])
                ])
            ])
        ])
    ])
}

public func jsonString<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
}

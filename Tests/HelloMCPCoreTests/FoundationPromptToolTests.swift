import HelloMCPCore
import MCP
import Testing

@Suite("Foundation prompt tool contract")
struct FoundationPromptToolTests {
    @Test("Input schema is strict and requires prompt")
    func inputSchemaContract() throws {
        let schema = try #require(promptToolInputSchema().objectValue)
        #expect(schema["additionalProperties"]?.boolValue == false)

        let required = try #require(schema["required"]?.arrayValue)
        #expect(required.contains(.string("prompt")))

        let properties = try #require(schema["properties"]?.objectValue)
        #expect(properties["temperature"] != nil)
        #expect(properties["maximumResponseTokens"] != nil)
        #expect(properties["sessionId"] != nil)
    }

    @Test("Output schema includes structured response fields")
    func outputSchemaContract() throws {
        let schema = try #require(promptToolOutputSchema().objectValue)
        let properties = try #require(schema["properties"]?.objectValue)

        #expect(properties["response"] != nil)
        #expect(properties["sessionId"] != nil)
        #expect(properties["durationMs"] != nil)
        #expect(properties["modelAvailable"] != nil)
        #expect(properties["availability"] != nil)
        #expect(properties["warnings"] != nil)
        #expect(properties["error"] != nil)
    }

    @Test("Valid arguments parse")
    func validArgumentsParse() throws {
        let request = try PromptToolRequest.parse(arguments: [
            "prompt": .string("Say hello"),
            "instructions": .string("Be brief"),
            "sessionId": .string("prompt-eval_1"),
            "resetSession": .bool(true),
            "maximumResponseTokens": .int(64),
            "temperature": .double(0.2)
        ])

        #expect(request.prompt == "Say hello")
        #expect(request.instructions == "Be brief")
        #expect(request.sessionId == "prompt-eval_1")
        #expect(request.resetSession)
        #expect(request.maximumResponseTokens == 64)
        #expect(request.temperature == 0.2)
    }

    @Test("Missing prompt is rejected")
    func missingPromptRejected() throws {
        #expect(throws: PromptToolValidationError(code: "missing_prompt", message: "Missing required string argument: prompt")) {
            try PromptToolRequest.parse(arguments: [:])
        }
    }

    @Test("Invalid session ID is rejected")
    func invalidSessionIDRejected() throws {
        #expect(throws: PromptToolValidationError.self) {
            try PromptToolRequest.parse(arguments: [
                "prompt": .string("Say hello"),
                "sessionId": .string("bad session")
            ])
        }
    }

    @Test("Invalid maximumResponseTokens is rejected")
    func invalidMaximumResponseTokensRejected() throws {
        #expect(throws: PromptToolValidationError.self) {
            try PromptToolRequest.parse(arguments: [
                "prompt": .string("Say hello"),
                "maximumResponseTokens": .int(0)
            ])
        }
    }

    @Test("Invalid temperature is rejected")
    func invalidTemperatureRejected() throws {
        #expect(throws: PromptToolValidationError.self) {
            try PromptToolRequest.parse(arguments: [
                "prompt": .string("Say hello"),
                "temperature": .double(1.1)
            ])
        }
    }
}

# HelloMCP
A simple MCP server in Swift, running on macOS

## Introduction

For my current use-case — and to better understand the Model Context Protocol (MCP) — I built a small MCP tool that processes a string using the Apple Foundation Models. I used the [official Swift SDK for Model Context Protocol servers and clients](https://github.com/modelcontextprotocol/swift-sdk), and the result is a minimal, working MCP server you can use as a reference.

## The Use-Case

I am using this MCP server with Codex as *Tool-augmented prompt evolution*: Codex generates or rewrites prompts, and the server immediately evaluates them in Apple’s Foundation Models. This enables fast iteration and hands-free prompt testing.

## Using the Server

Build the server by executing `swift build -c release`. The executable will be in `.build/release/hellomcp`, you can copy it anywhere you like.

To examine the server with the [MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector), run it like this: `npx @modelcontextprotocol/inspector ${PATH_TO_HELLOMCP}`

For Codex, add HelloMCP by running: `codex mcp add HelloMCP ${PATH_TO_HELLOMCP}`. Codex will then use MCP for example for this prompt: `Run the prompt "Say Hello" with Apple Foundation Models`.

Quick verification once it is running:
- Check platform/model availability via the status resource:
  ```
  codex mcp read HelloMCP resource://system/status
  ```
  You should see JSON fields like `"Apple Intelligence available": "true"` and `"Foundation Model available": "true"`.
- Test a tool call. In Codex: `codex mcp call HelloMCP applechat --prompt "Say Hello"` (add `--instructions "Be brief"` if you like). In the Inspector, open Resources → `resource://system/status` to confirm availability, then Tools → `applechat` and send a prompt. Either path should return a model response if everything is wired correctly.

## Challenges

The documentation of the  [MCP Swift SDK]((https://github.com/modelcontextprotocol/swift-sdk)) still follows an older version of the specification and does not match the current [MCP 2025-06-18 tool schema](https://modelcontextprotocol.io/specification/2025-06-18/server/tools).

For example, the documentation shows a tool defined like this:
```swift
        Tool(
            name: "weather",
            description: "Get current weather for a location",
            inputSchema: .object([
                "properties": .object([
                    "location": .string("City name or coordinates"),
                    "units": .string("Units of measurement, e.g., metric, imperial")
                ])
            ])
        )
```
However:
-	The [MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector) will not list tools defined in this format.
-	The root cause is that the schema must follow the JSON Schema–shaped structure expected by current MCP servers, including explicit "type" annotations and object-typed field descriptors.

The corrected version looks like this:
```swift
        Tool(
            name: "weather",
            description: "Get current weather for a location",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "location": .object([
                        "description": .string("City name or coordinates"),
                        "type": .string("string"),
                        "units": .string("Units of measurement, e.g., metric, imperial")
                    ])
                    
                ])
            ])
        )
```
Key differences compared to the documentation:
1.	Every schema object must declare its "type" explicitly.
2.	Properties must themselves be JSON-object descriptors, not bare `.string(…)` values.
3.	Descriptions belong inside the dictionary of each property, not as the property value.
4.	Adding "required" improves compatibility with the Inspector and many clients.

Once defined this way, the MCP Inspector correctly discovers and validates the tool.

---

That’s it — a tiny but complete MCP server in Swift, and a working reference for defining tools using the up-to-date schema.

![The MCP Inspector using the applechat tool](Inspector.png "MCP Inspector")
Have fun building your own MCP tools! If you run into issues, feel free to ask — I’m happy to help.

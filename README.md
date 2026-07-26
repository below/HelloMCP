# HelloMCP

HelloMCP is a local stdio MCP server for using Apple's on-device Foundation Models from any compatible MCP client, such as Codex or Claude Code.

## Purpose

The server is designed for tool-augmented prompt evolution: an MCP client can draft or revise a prompt, call Apple Foundation Models locally, inspect the result, and iterate.

HelloMCP exposes one tool:

- `run_foundation_model_prompt`: evaluates a prompt with Apple Foundation Models.

It also exposes one resource:

- `resource://system/status`: reports server, OS, model availability, active session count, and the last tool error.

## Requirements

- macOS 26 or newer for Foundation Models execution.
- Apple Intelligence and the system language model must be available on the machine.
- Swift 6 and the Swift Package Manager.
- An MCP client, such as Codex.

## Build

```bash
swift build -c release
```

The executable is created at:

```bash
.build/release/hellomcp
```

## Add To Codex

Use the absolute path to the built executable:

```bash
codex mcp add HelloMCP /absolute/path/to/.build/release/hellomcp
```

Equivalent `~/.codex/config.toml` entry:

```toml
[mcp_servers.HelloMCP]
command = "/absolute/path/to/.build/release/hellomcp"
startup_timeout_sec = 20
tool_timeout_sec = 120
```

Restart Codex after changing MCP configuration. In the Codex TUI, use `/mcp` to confirm the server is connected.

## Verify Status

```bash
codex mcp read HelloMCP resource://system/status
```

The response is JSON and includes fields such as `foundationModelsAvailable`, `availability`, `activeSessionCount`, and `lastError`.

## Conversational Use

Once the server is connected, you can ask your MCP client to use Apple Foundation Models in plain language. In Codex, for example:

```text
Evaluate the prompt: "Wish the user a good morning" with Apple Foundation Models.
```

Codex should route that request to `run_foundation_model_prompt` and return the local model response.

## Call The Tool

Stateless call:

```bash
codex mcp call HelloMCP run_foundation_model_prompt \
  --prompt "Say hello in one short sentence." \
  --instructions "Be brief."
```

Use optional generation controls:

```bash
codex mcp call HelloMCP run_foundation_model_prompt \
  --prompt "Give three alternative titles for this README." \
  --temperature 0.4 \
  --maximumResponseTokens 128
```

Use explicit temporary context across calls:

```bash
codex mcp call HelloMCP run_foundation_model_prompt \
  --sessionId prompt-eval-1 \
  --prompt "Remember that the target audience is Swift developers."

codex mcp call HelloMCP run_foundation_model_prompt \
  --sessionId prompt-eval-1 \
  --prompt "Rewrite the previous answer for that audience."
```

Reset a named session before using it:

```bash
codex mcp call HelloMCP run_foundation_model_prompt \
  --sessionId prompt-eval-1 \
  --resetSession true \
  --prompt "Start a fresh prompt evaluation."
```

Session state is in memory only. It lasts only while the MCP server process remains alive.

## Tool Arguments

| Name | Required | Type | Notes |
| --- | --- | --- | --- |
| `prompt` | Yes | String | Prompt to evaluate. |
| `instructions` | No | String | Foundation Models session instructions. |
| `sessionId` | No | String | Enables explicit multi-turn context. Use ASCII letters, digits, `_`, `-`, or `.`. |
| `resetSession` | No | Boolean | Recreates the named session before responding. |
| `maximumResponseTokens` | No | Integer | Must be positive. Can truncate output. |
| `temperature` | No | Number | Must be between `0` and `1`, inclusive. Omit for the system default. |

## Result Shape

The tool returns native MCP `structuredContent` and a text summary. The structured content has this shape:

```json
{
  "response": "...",
  "sessionId": null,
  "stateless": true,
  "durationMs": 1234,
  "modelAvailable": true,
  "availability": "available",
  "warnings": [],
  "error": null
}
```

On failure, `error` contains a stable `code` and readable `message`.

## Inspect With MCP Inspector

```bash
npx @modelcontextprotocol/inspector /absolute/path/to/.build/release/hellomcp
```

Use the Inspector to verify tool schema, output schema, structured content, and `resource://system/status`.

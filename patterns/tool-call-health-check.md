# Health checks that exercise tool calling

Kind: pattern.

## Problem

A model-serving stack passes its health check on plain completions while the routing or config layer silently drops tool calls, which is the capability every agent turn depends on.

## Context

Any proxy, gateway or local model server used by agents, MCP clients or chat-with-tools front ends.

## The pattern

- Include at least one prompt per tool-using model that must produce a `tool_calls` response, and assert on that structure, not on the text.
- Send it through the same proxy path production traffic uses.
- Test streaming and non-streaming separately; a routing bug can affect one and not the other.
- When a route or model change touches tool calling, ask for a tool-call transcript before approving, not a plain completion.
- Change only the routes the probe shows broken; probe the others and leave them alone if they pass.

## Evidence

Observed: one local model proxy, 2026-09, from the review log. A route on the server's plain-completion endpoint returned empty tool calls for every tool prompt while plain completions passed. A dedicated probe through the proxy, streaming and non-streaming, found it; switching that route to the chat endpoint raised the eval pass rate from 2 of 6 prompts to 5 of 6. A second model on the old endpoint was probed, already returned tool calls, and was left unchanged. n = 6 prompts, one stack.

## When it does not hold

A stack with no tool-using consumers only needs completion checks.

## Related

- [eval-scorer-review](eval-scorer-review.md)
- [stub-only-setup-tests](stub-only-setup-tests.md)

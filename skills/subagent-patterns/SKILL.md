---
name: subagent-patterns
description: Task tool delegation patterns for spawning subagents. Use when planning parallel work, delegating research, offloading context-heavy exploration, or coordinating multi-agent workflows. Trigger phrases include "spawn agent", "delegate to agent", "parallel agents", "use subagent".
---

## When to Use

- Delegating independent subtasks for parallel execution
- Heavy research/documentation fetching that would bloat main context
- Exploratory tasks (codebase scanning, file pattern matching)
- Any task where you want distilled results, not raw output

## When NOT to Use

- Quick single commands (<2 sec execution)
- When you need raw output in main context
- Dependent tasks that must run sequentially
- Simple file reads (use Read tool directly)
- Tasks requiring tight control over implementation

## Subagent Types

Use the `Task` tool with `subagent_type`:

| Type | Use Case |
|------|----------|
| `general` | Multi-step research, complex code searches, parallel units of work |
| `explore` | Fast codebase exploration, file pattern matching, keyword searches |
| `Plan` | Design implementation plans, identify critical files |
| `debugger` | Investigate errors, test failures, unexpected behavior |
| `tester` | Run tests, enforce coverage, co-locate tests with code |

## Patterns

### Parallel Delegation

When tasks are independent, spawn multiple agents in a single message:

```
Task(subagent_type="explore", prompt="Find all API routes")
Task(subagent_type="explore", prompt="Find all database models")
```

### Research Delegation

Keep main context clean by delegating heavy research:

```
Task(
  subagent_type="general",
  prompt="Research how auth middleware works in this codebase.
         Return: file locations, key functions, flow diagram."
)
```

### Parallel Fetch Pattern

For 3+ independent data sources:

```
Task(
  subagent_type="general",
  prompt="Gather these independent items: [list].
         Return structured summary of findings."
)
```

## Key Insight

Subagents return summaries to main conversation, keeping context focused on decision-making rather than raw data parsing.

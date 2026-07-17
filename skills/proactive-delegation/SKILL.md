---
name: proactive-delegation
description: Patterns for delegating independent subtasks to subagents when planning multi-part tasks. Use when working on tasks with multiple independent components like code + tests, multi-file edits, or research + implementation. Trigger phrases include "parallel work", "delegate tasks", "run in parallel".
---

## When to Use

When working on tasks with multiple independent components:
- Code changes + tests
- Multiple file edits across different areas
- Research + implementation
- Any task where subtasks don't depend on each other's output

## When NOT to Use

- Single-file changes
- Tasks requiring sequential steps (B depends on A's output)
- Trivial tasks (<2 min of work)
- When tight control over implementation details is needed
- When user wants to review each step

## Pattern

1. Identify independent subtasks when planning (TodoWrite)
2. Start the first subtask yourself
3. Immediately delegate independent subtasks to `general` subagents in parallel

```
Task(
  description="Write unit tests for X",
  prompt="Write unit tests for [feature]. Look at existing tests in [path] for patterns. 
         The implementation is in [file]. Cover: [cases]. Edit the test file directly.",
  subagent_type="general"
)
```

## Examples

### Issue with code + tests
```
1. You: Make the code changes
2. Delegate: "Write unit tests for the changes I made to [file]. 
   Follow patterns in [existing-test-file]. Cover [error cases, success cases]."
```

### Multi-file refactor
```
1. You: Refactor file A
2. Delegate: "Refactor file B following same pattern as file A"
3. Delegate: "Refactor file C following same pattern as file A"
```

## Why

- Reduces total time for multi-part tasks
- Subagents work in parallel while you focus on primary work
- User explicitly requested delegation when appropriate
- Matches how teams naturally divide work

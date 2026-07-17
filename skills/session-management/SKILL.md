---
name: session-management
description: Manage long coding sessions with context checkpoints, state preservation, and handoff patterns. Use when session exceeds 30 minutes, context feels bloated, preparing to hand off work, or needing to preserve state across breaks.
---

# Session Management

Patterns for maintaining coherent context in long coding sessions and multi-agent workflows.

## When to Use

- Session exceeds 30 minutes of active work
- Context window feels bloated (slow responses, lost details)
- Preparing to hand off work to another session
- Returning to work after a break
- Complex task spanning multiple areas of codebase

## When NOT to Use

- Quick single-file edits (<15 min)
- Simple questions or lookups
- Tasks fully tracked in TodoWrite

## Core Patterns

### 1. Context Checkpoints

Create checkpoints at natural milestones using TodoWrite + summary:

```
TodoWrite: Mark current task completed
Summary: "Checkpoint: [what's done], [what's next], [key decisions made]"
```

Checkpoint triggers:
- Completed a TodoWrite item
- Made architectural decision
- Discovered unexpected complexity
- About to switch focus areas

### 2. State Preservation

Before breaks or handoffs, capture:

| State | How to Preserve |
|-------|-----------------|
| Current task | TodoWrite with status |
| Key decisions | Inline comment or summary |
| Blockers | Note in TodoWrite or ask user |
| Files touched | Git status captures this |
| Next steps | TodoWrite pending items |

### 3. Context Compression

When responses slow or details get lost:

1. Summarize completed work (bullet points)
2. State current focus clearly
3. List only relevant pending items
4. Drop context for completed/irrelevant areas

Trigger phrase: "Let me summarize where we are..."

### 4. Handoff Pattern

When ending session or switching context:

```markdown
## Handoff Summary

**Completed:**
- [bullet list]

**In Progress:**
- [current task + state]

**Pending:**
- [remaining items]

**Key Decisions:**
- [architectural choices made]

**Files Changed:**
- [list from git status]

**Next Steps:**
- [concrete actions for resumption]
```

## Agent Integration

### Context-Manager Agent

For complex multi-agent workflows, delegate state management:

```
Task(
  subagent_type="context-manager",
  prompt="Capture current session state. We're at [milestone].
         Key decisions: [list]. Create context brief for [next focus area]."
)
```

Use when:
- Coordinating 3+ agents
- Session exceeds 10k tokens of context
- Need to create focused briefs for specialized agents

### TodoWrite Integration

TodoWrite is your primary state tracking tool:

```
TodoWrite([
  {content: "Implement auth flow", status: "completed", activeForm: "Implementing auth flow"},
  {content: "Add unit tests for auth", status: "in_progress", activeForm: "Adding auth unit tests"},
  {content: "Update API docs", status: "pending", activeForm: "Updating API docs"}
])
```

Rules:
- One `in_progress` at a time
- Mark completed immediately (don't batch)
- Add items as you discover them
- Remove irrelevant items

## Long Session Workflow

### Start of Session
1. Review TodoWrite state
2. Check git status for uncommitted work
3. Read relevant files into context
4. State current focus aloud

### During Session
1. Update TodoWrite on task transitions
2. Create checkpoints at milestones
3. Compress context when bloated
4. Ask user to clarify when ambiguous

### End of Session
1. Mark current TodoWrite state
2. Commit if at stable point
3. Create handoff summary if incomplete
4. Suggest next session start point

## Anti-Patterns

- Keeping completed work in full context
- Not using TodoWrite for multi-step tasks
- Trying to hold all details in working memory
- Skipping checkpoints on long tasks
- Batching TodoWrite updates

## Quick Reference

| Situation | Action |
|-----------|--------|
| Task complete | Mark TodoWrite done immediately |
| Milestone reached | Create checkpoint summary |
| Context bloated | Compress and summarize |
| Focus switching | Update TodoWrite, state new focus |
| Ending session | Handoff summary + commit if stable |
| Resuming session | Review TodoWrite + git status |

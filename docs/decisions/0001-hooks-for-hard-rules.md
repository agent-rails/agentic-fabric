# 0001: Hard rules are hooks, not prompt instructions

Status: accepted.

## Decision

A rule whose violation is costly or hard to undo (opening an unreviewed PR, merging a moved head, editing the guardrails) is enforced by a PreToolUse hook. Prompts may explain the rule; they never carry it alone.

## Rejected

- Prompt-only rules. A model can misread, deprioritise or be talked out of an instruction, and nothing records that it was.
- Permission rules only. `deny` patterns match command text without parsing it and cannot check state such as whether a PR head moved.

## Consequences

Each gate is a small program with a test suite. Hooks run on every matching tool call, so they must be fast: the branch gate exits on a grep prefilter for commands that cannot create a branch.

## Would change if

Claude Code offered a first-class policy engine that could express these checks with equal precision.

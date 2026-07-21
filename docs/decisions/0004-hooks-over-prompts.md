# ADR-0004 — Hooks over prompts for rules that must not be skipped

Status: Accepted · Applies principle: [Hooks over prompts](../DESIGN-PRINCIPLES.md#2-hooks-over-prompts-for-anything-that-must-not-be-skipped)

## Context

Some rules are hard gates: never push to a non-`<alias>/` branch, never open a non-draft PR, never let an agent edit the rubric it's graded against. An LLM ignores a plainly-stated prompt instruction often enough (~1 in 5) that "the system prompt says don't" is not a control for anything whose violation is costly. The more important the rule, the less acceptable a 20% miss rate.

Claude Code exposes PreToolUse / PostToolUse hooks — deterministic shell scripts that fire on a tool call and can deny it before it runs. The question is which rules belong in a prompt and which belong in a hook.

## Options

1. **All rules in prompts.** One place, easy to read, no shell code. But every hard gate inherits the LLM's miss rate. Unacceptable for irreversible or trust-critical actions.
2. **All rules in hooks.** Maximally reliable, but most rules are judgment-shaped ("draft in the user's tone," "downgrade unverified blockers") and can't be expressed as a deterministic tool-call check. Over-hooking turns nuance into brittle pattern-matching.
3. **Split by rule shape (chosen).** Hard, mechanically-checkable gates → hooks. Judgment-shaped rules → prompts.

## Decision

Option 3. A rule goes in a hook when it is (a) a hard gate where a miss is costly and (b) checkable from the tool-call payload. Current hooks (`scripts/`):

- `enforce-branch-prefix.sh` — deny agent-created branches not prefixed `<alias>/`.
- `gh-pr-create-gate.sh` — deny `gh pr create` without `--draft`; enforces the review-first workflow. Strips heredoc bodies first so a `gh pr create` string *inside* a PR body doesn't false-trigger.
- `protect-gate-pages.sh` — deny Edit/Write to the review rubric and shared-wiki unless a fresh human unlock marker exists (`touch ~/.claude/gate-unlock`, 15-min validity). Verifier-immutability: the agent graded by the rubric can't edit the rubric.
- `scan-skill.sh` — skill scanner.

Everything judgment-shaped stays in the prompts (`rules/`, agent definitions).

## Consequences

- Hard gates become deterministic. The model *cannot* proceed through a denied tool call — reliability goes from ~80% to 100% for the gated action. This is the mechanism that makes the human-gate principle ([ADR-0006](0006-outbound-human-gate.md)) and the wiki rubric ([ADR-0003](0003-wiki-as-memory.md)) actually hold.
- Hooks are code with their own failure modes, so they **must fail loud**. `protect-gate-pages.sh` falls back to a raw substring match and emits a degraded-mode warning if `jq` is missing — it never silently no-ops. A hook that fails open is worse than no hook, because it advertises protection it isn't providing.
- Known limit, stated honestly: these defend against *accidental / silent* drift, not a deliberate bypass by a Bash-capable agent. Same trust model as keeping an evaluator script out of the training loop's write scope. The gate raises the cost of accidental violation to infinite and the cost of deliberate violation to "you have to mean it."
- Hooks fire only on *agent* tool calls; user-typed terminal commands are unaffected. The gate constrains the agent, not the human.
- Wiring is per-machine (`~/.claude/settings.json`); the repo ships a template at `docs/settings.hooks.example.json`.

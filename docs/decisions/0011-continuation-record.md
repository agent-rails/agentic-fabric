# ADR-0011 — Structured continuation record for in-flight task resume

Status: Accepted · Applies principle: [Hooks over prompts for anything that must not be skipped](../DESIGN-PRINCIPLES.md#2-hooks-over-prompts-for-anything-that-must-not-be-skipped)

## Context

Resuming an interrupted background task — one that stalled or hit a session limit — currently means replaying the entire prior transcript to a fresh instance. Recovery cost is proportional to the size of the *conversation* that produced the work, not the size of the *decision* being resumed. The underlying need is to decouple those two: make resume cost proportional to a small decision record, and leave the transcript as a forensic fallback rather than the default continuation mechanism.

The efficiency half of that claim is unmeasured (desk research only; this system has no instrumented A/B token number yet, and the resume path should log real deltas going forward). The record survives on its *verified* axis alone: recovery-durability. Manual continuation records were used for three real resumes in practice, operator-discipline-only, and the durability benefit held. This ADR does not oversell the token-efficiency angle — schema fields that would only exist to serve token optimization are deferred until a real measurement earns them.

One genuine safety finding drove the shape below: a structured record captures *decisions* but can silently drop a *constraint* stated once early in a task ("do not touch the live gateway") that a full transcript replay would have preserved. A field alone does not fix this — a field is a container, not an answer to who populates it and when.

## Schema

`.agents/tasks/<agentId>.json`, keyed on the spawned `agentId` (verified available at dispatch, see the spike below), not on a human-chosen name:

```json
{
  "agent_id": "acf6ee6baa8099214",
  "goal": "<the dispatch prompt, truncated>",
  "constraints": ["do not modify the live config", "stop before opening the PR"],
  "decisions_so_far": [],
  "next_action": null,
  "status": "active"
}
```

Sized to exactly what the real resumes needed: task identity, goal, decisions accumulated so far, the next action, and — per the safety finding — an explicit slot for standing constraints that must survive into the record rather than be assumed. No retry counts, no distributed-state fields, no multi-node coordination: this is a single-orchestrator, single-machine system, and importing a durable-execution checkpoint schema wholesale would be ceremony for a threat model this system does not have.

`.agents/tasks/` is gitignored — truly ephemeral, local-only, deleted on task completion. It loses cross-machine durability, which is not needed yet (single operator, single machine). This is the honest framing of operational state; git-tracking it would contradict the "pruned on completion" claim, since deletion does not remove a file from git history.

## Decision

### Creation is mechanized, not remembered

Creation is a **PostToolUse hook on the `Agent` tool** (`auto-create-task-record.py`), not a manually-invoked command. A `create()` left as a remembered follow-up step is the exact "a prompt is not a control" gap [Principle 2](../DESIGN-PRINCIPLES.md#2-hooks-over-prompts-for-anything-that-must-not-be-skipped) and [ADR-0004](0004-hooks-over-prompts.md) exist to close — and it compounds badly, because the dominant failure path (a human forgets to create the record) is exactly the path where the resume-time check would have no record to inspect. Mechanizing creation removes that path entirely: a record exists for every real dispatch.

The hook reads `tool_response.agentId` for the key and `tool_input.prompt` for the goal. `task-record.py` correspondingly shrinks to three operations — `append-decision`, `read`, `complete` — with creation no longer a manual command.

### Constraints are captured structurally at dispatch time

Constraints are extracted from the dispatch prompt structurally, not via NLP: any prompt containing a delimited `HARD CONSTRAINTS:` section has that section parsed into the constraints list (a marker line, then list items, until a blank line or the next section marker). A prompt with no such section produces `constraints: []` — which is exactly the case the resume-time hook must catch. Capturing at dispatch time aligns with the user-is-orchestrator model ([ADR-0002](0002-user-is-orchestrator.md)): the human stating the task is the one who knows the hard constraints, and states them where they are already writing the prompt.

### Fail-loud only in one narrow window; fail-open everywhere else

The resume-time check is a **PreToolUse hook on `SendMessage`** (`enforce-resume-constraints.py`). It reads the record for `tool_input.to` and:

- **No record** → allow, silently. Covers a name-based resume with no matching `agentId` file, and any genuinely untracked or pre-mechanism resume. Both fail open, honestly.
- **Record with non-empty `constraints`** → allow.
- **Record with `constraints: []`** → **block**: "no recorded constraints for {agent_id} — verify before acting, do not assume none exist".

This is deliberately *not* "fail-loud on resume" flatly. Fail-loud fires only in the narrow window where a record exists AND its constraints are empty. Every other case is fail-open, consistent with this repo's existing hook convention ([ADR-0008 depth gate](0010-orchestrator-depth-gate.md), the branch-prefix hook — both fail open on any parse ambiguity). The block uses this repo's standard deny mechanism: a `hookSpecificOutput.permissionDecision: "deny"` JSON on stdout, exit 0.

## Evidence — the live spike this design rests on

The load-bearing assumption is that a PostToolUse hook actually *fires* on the `Agent` tool and actually *receives* `tool_response.agentId` — not merely that the field exists somewhere. That required a live spike, not a desk pass. A temporary diagnostic `PostToolUse:Agent` hook logging raw stdin was added (live config backed up first), two throwaway agents were run, and the settings were restored from backup afterward and verified byte-identical via `diff`:

- **Foreground dispatch:** `PostToolUse` fired; `tool_response` carried `"status": "completed"` and `"agentId": "a53c2bebf2313fa4c"`.
- **Background dispatch:** `PostToolUse` fired **immediately at dispatch**, before the background work started — `"status": "async_launched"` with `"agentId": "acf6ee6baa8099214"` already populated. Better than the design needed: the record is created at true dispatch time, not after the fact.
- **Bonus signal:** the same `tool_response` included real cache-usage fields (`cache_creation_input_tokens`, `cache_read_input_tokens`, `ephemeral_5m_input_tokens`), confirming subagent dispatch uses prompt caching at a 5-minute ephemeral tier. Relevant evidence for whenever the deferred token-efficiency measurement gets picked up — not conclusive alone, but no longer purely speculative.

The `agentId` key is `agentId` (camelCase) in the response and is present at both `completed` and `async_launched` status. The resume path this session used `SendMessage` targeting that same raw `agentId` 100% of the time, which is why keying on `agentId` matches real usage.

## Non-goals

- **In-flight resume only, not post-mortem lineage.** This serves resuming a task that is still meaningfully alive. A durable audit trail of dead tasks is a distill-to-wiki step, out of scope here (same source-of-truth boundary [ADR-0003](0003-wiki-as-memory.md) settled).
- **No reaper for orphaned records.** A task that dies without calling `complete()` leaves its record behind with nothing to clean it up. This is acceptable and stated plainly, not silently implied away — the records are ephemeral and local, and a stale one costs a stray file, not a wrong action.
- **Gap C (a full task-runner) is out of scope, deferred-until-earned.** A scheduler/runner that owns task lifecycle, retries, and state transitions is a materially larger system than a checkpoint file, and this single-operator setup has not demonstrated the need. It is not built here and should not be pulled in as ceremony.

## Residual gap, named honestly

`SendMessage` accepts both a raw `agentId` and a name, but records are keyed only on `agentId`. A resume performed **by name** still misses the lookup — `read()` only matches an exact `agentId` filename — and therefore fails open when it might have wanted to block. The mechanization fixes the dominant failure mode (the record never getting created), not the "operator resumes by the wrong kind of identifier" one. This session's real pattern was 100% `agentId`-based, so the residual is small in practice but not zero. It is recorded here as a known limitation rather than silently accepted; closing it would require also keying (or aliasing) records by name, which is not built until a name-based resume actually misses in practice.

## Consequences

- **Alarm fatigue is expected and intended, not a bug.** If the `HARD CONSTRAINTS:` convention is only informally followed at dispatch, most records land with `constraints: []`, and every resume of those tasks blocks. That is the fail-loud behavior working as designed. The practical mitigation is dispatch-prompt discipline — state the constraints explicitly, even if just "none" — the same category of discipline this system already relies on elsewhere. Worth stating plainly here so it is not later rediscovered as a false alarm and "fixed" by weakening the gate.
- Recovery cost drops toward the size of the decision record for tasks that maintain one; the transcript becomes the forensic fallback, not the default path.
- The record is honest operational state: ephemeral, local, uncommitted. It does not claim durability it does not have.
- A revisit trigger is named for the residual: the first real name-based resume that misses a record. Until then, agentId-keying matches observed usage and adding name-keying would be speculative surface.

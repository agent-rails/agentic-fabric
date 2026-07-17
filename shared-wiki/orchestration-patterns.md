# Orchestration Patterns

Reference catalog of agent orchestration patterns and anti-patterns. Read this before adding a new slash command that coordinates multiple personas, or before introducing a new persona that "wraps" existing ones.

The governing rule: **the user (or a slash command) is the orchestrator. Personas do not invoke other personas.** Skills are mandatory hops inside a persona's workflow. The cascade exception is documented at the bottom — sentinel cascades to spock/architect-reviewer/ai-architect as Pattern 3 (parallel fan-out with synthesizer), not as Anti-pattern B.

> **Source:** lifted (with adaptation) from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) `references/orchestration-patterns.md`. Original content is harness-agnostic; the *stack mapping* appendix is local. Re-sync upstream periodically.

---

## Endorsed patterns

### 1. Direct invocation (no orchestration)

Single persona, single perspective, single artifact. The default and the cheapest option.

```
user → reviewer → report → user
```

**Use when:** the work is one perspective on one artifact and you can describe it in one sentence.

**Examples:**
- "Review this PR" → `sentinel` (single-pass mode)
- "Triage messages" → `voltage`
- "Find every call site of this deprecated API" → `Explore`

**Cost:** one round trip. The baseline you should always compare orchestrated patterns against.

---

### 2. Single-persona slash command

A slash command that wraps one persona with the project's skills. Saves the user from re-explaining the workflow every time.

```
/review-pr → sentinel (with PR context + wiki) → report
```

**Use when:** the same single-persona invocation happens repeatedly with the same setup.

**Examples in this stack:** `/review-pr`, `/draft-pr-fixes`, `/triage`.

**Cost:** same as direct invocation. The slash command is just a saved prompt.

**Anti-signal:** if the slash command's body is mostly "decide which persona to call," delete it and let the user call the persona directly.

---

### 3. Parallel fan-out with synthesizer

Multiple personas operate on the same input concurrently, each producing an independent report. A merge step (in the main agent's context, or a dedicated synthesizer) synthesizes them into a single decision.

```
                         ┌─→ architect-reviewer ─┐
sentinel → fan out  ─────┼─→ ai-architect       ─┤→ sentinel (synthesizer) → verdict
                         └─→ spock              ─┘
```

**Use when:**
- The sub-tasks are genuinely independent (no shared mutable state, no ordering dependency)
- Each sub-agent benefits from its own context window
- The merge step is small enough to stay in the main context (or has a dedicated synthesizer agent)
- Wall-clock latency matters

**Examples in this stack:** sentinel's PR-review cascade (sentinel = synthesizer; architect-reviewer + ai-architect + spock = peer reviewers).

**Cost:** N parallel sub-agent contexts + one merge turn. Higher than direct invocation, but faster wall-clock and produces better reports because each sub-agent stays focused on its single perspective.

**Validation checklist before adopting this pattern:**
- [ ] Can I run all sub-agents at the same time without ordering issues?
- [ ] Does each persona produce a different *kind* of finding, not just the same finding from a different angle?
- [ ] Will the merge step fit in the main agent's remaining context?
- [ ] Is the user's wait time long enough that parallelism is actually noticeable?
- [ ] Is there a convergence bound on the cascade (cycle cap, severity gating)?

If any answer is "no," fall back to direct invocation or a single-persona command.

---

### 4. Sequential pipeline as user-driven slash commands

The user runs slash commands in a defined order, carrying context (or commit history) between them. There is no orchestrator agent — the user IS the orchestrator.

```
user runs:  /review-pr  →  /draft-pr-fixes  →  (review patches, cherry-pick)  →  push
```

**Use when:** the workflow has dependencies (each step needs the previous step's output) and human judgment between steps adds value.

**Examples in this stack:** `/review-pr` → `/draft-pr-fixes` (review then fix); `/triage` → daily-report → standup.

**Cost:** one sub-agent context per step. Free for the orchestration layer because there is no orchestrator agent.

**Why not automate it:** an LLM "lifecycle orchestrator" would (a) lose nuance between steps because it has to summarize for hand-off, (b) skip the human checkpoints that catch wrong-direction work early, and (c) double the token cost via paraphrasing turns.

---

### 5. Research isolation (context preservation)

When a task requires reading large amounts of material that shouldn't pollute the main context, spawn a research sub-agent that returns only a digest.

```
main agent → research sub-agent (reads 50 files) → digest → main agent continues
```

**Use when:**
- The main session needs to stay focused on a downstream task
- The investigation result is much smaller than the input it consumes
- The decision quality benefits from the main agent having room to think after

**Examples:** "Find every call site of this deprecated API across the monorepo," "Summarize what these 30 ADRs say about caching."

**On Claude Code, use the built-in `Explore` subagent** rather than defining a custom research persona. `Explore` runs on Haiku, is denied write/edit tools, and is purpose-built for this pattern. Define a custom research subagent only when `Explore` doesn't fit (e.g. you need a domain-specific system prompt the model wouldn't infer — like the local `researcher` agent).

---

## Claude Code compatibility

### Subagents vs. Agent Teams

Claude Code has two parallelism primitives. Pattern 3 (parallel fan-out with synthesizer) maps to **subagents**. If you need teammates that talk to each other, use **Agent Teams** instead.

| | Subagents | Agent Teams |
|--|-----------|-------------|
| Coordination | Main agent fans out, sub-agents only report back | Teammates message each other, share a task list |
| Context | Own context window per subagent | Own context window per teammate |
| When to use | Independent tasks producing reports | Collaborative work needing discussion |
| Status | Stable | Experimental — requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| Cost | Lower | Higher — each teammate is a separate Claude instance |

### Platform-enforced rules

Two rules in this catalog aren't just convention — Claude Code enforces them:

- **"Subagents cannot spawn other subagents."** Anti-pattern B (persona-calls-persona) and Anti-pattern D (deep persona trees) cannot exist on Claude Code by construction.
- **"No nested teams"** — teammates cannot spawn their own teams.

This means contributors cannot accidentally build the anti-patterns. They'll just fail to load.

### Spawning multiple subagents in parallel

In Claude Code, parallel fan-out (Pattern 3) requires issuing **multiple Agent tool calls in a single assistant turn**. Sequential turns serialize execution.

---

## Anti-patterns

### A. Router persona ("meta-orchestrator")

A persona whose job is to decide which other persona to call.

```
/work → router-persona → "this needs a review" → sentinel → router (paraphrases) → user
```

**Why it fails:**
- Pure routing layer with no domain value
- Adds two paraphrasing hops → information loss + roughly 2× token cost
- The user already knew they wanted a review; they could have called `/review-pr` directly
- Replicates the work that slash commands already do

**What to do instead:** add or refine slash commands. Document intent → command mapping in `CLAUDE.md`.

---

### B. Persona that calls another persona (without synthesis)

A `sentinel` that internally invokes `voltage` when it sees a Slack reference, with no merge step.

**Why it fails:**
- Personas were designed to produce a single perspective; chaining them defeats that
- The summary the calling persona passes loses context the called persona needs
- Failure modes multiply (which persona's output format wins? whose rules apply?)
- Hides cost from the user

**What to do instead:** have the calling persona *recommend* a follow-up in its report. The user or a slash command runs the second pass. (Sentinel's cascade is *not* this anti-pattern — sentinel acts as synthesizer; see stack mapping below.)

---

### C. Sequential orchestrator that paraphrases

An agent that calls `/review-pr`, then `/draft-pr-fixes`, then pushes patches on the user's behalf.

**Why it fails:**
- Loses the human checkpoints that catch wrong-direction work
- Each hand-off summarizes context — accumulated drift over a long pipeline
- Doubles token cost: orchestrator turn + sub-agent turn for every step
- Removes user agency at exactly the points where judgment matters most (e.g. cherry-picking which scotty patches to apply)

**What to do instead:** keep the user as the orchestrator. Document the recommended sequence and let the user invoke each step.

---

### D. Deep persona trees

`/review-pr` calls a `pre-review-coordinator` that calls a `quality-coordinator` that calls `sentinel`.

**Why it fails:**
- Each layer adds latency and tokens with no decision value
- Debugging becomes a multi-level investigation
- The leaf personas lose context to multiple summarization steps

**What to do instead:** keep the orchestration depth at most 1 (slash command → personas). The synthesis happens in one designated agent (the slash command, the main session, or one synthesizer like sentinel).

---

## Decision flow

When considering a new orchestrated workflow, walk this flow:

```
Is the work one perspective on one artifact?
├── Yes → Direct invocation. Stop.
└── No  → Will the same composition repeat?
         ├── No  → Direct invocation, ad hoc. Stop.
         └── Yes → Are sub-tasks independent?
                  ├── No  → Sequential slash commands run by user (Pattern 4).
                  └── Yes → Parallel fan-out with synthesizer (Pattern 3).
                           Validate against the checklist above.
                           If any check fails → fall back to single-persona command (Pattern 2).
```

---

## When to add a new pattern to this catalog

Add a new entry only after:

1. You've used the pattern at least twice in real work
2. You can name a concrete artifact that demonstrates it
3. You can explain why an existing pattern wouldn't have worked
4. You can describe its anti-pattern shadow (what people will mistakenly build instead)

Premature catalog entries become aspirational documentation that no one follows.

---

## Stack mapping

Local appendix — how the personas in this workspace map onto the patterns above. Update this when adding or retiring personas.

| Persona | Model | Role | Pattern usage |
|---------|-------|------|---------------|
| `sentinel` | opus | PR-review synthesizer + DevSecOps lens | **Synthesizer in Pattern 3.** Cascades to peers (`architect-review`, `ai-architect`, `spock`) on security/architectural-impact paths, then merges. Cycle-bounded (3-cap, severity gating, convergence detection). |
| `architect-review` | opus | Architectural consistency reviewer | Pattern 3 peer (called by sentinel). Direct invocation also valid. |
| `ai-architect` | opus | LLM/agent-impact reviewer | Pattern 3 peer (called by sentinel) on AI-impact paths. |
| `spock` | opus | Cross-vendor reviewer (codex-backed) | Pattern 3 peer (called by sentinel) for vendor diversity. **Never invoked directly by orchestrator** — by design. |
| `scotty` | opus | Cross-vendor patch drafter (codex-backed) | Pattern 4 — user runs `/review-pr` then `/draft-pr-fixes`. Read-only; never applies. |
| `voltage` | opus | Multi-channel triage / chief of staff | Pattern 2 (`/triage`). Fans out internally to `voltage-fetcher` (Pattern 5: research isolation per channel). |
| `voltage-fetcher` | haiku | Per-channel message fetcher | Pattern 5 (research isolation). Async fire-and-forget per channel. Haiku is correct here — input large, output a digest. |
| `voltage-reporter` | sonnet | Daily/weekly report generator | Pattern 2 internals. Not user-facing. |
| `voltage-scribe` | sonnet | Voltage wiki maintainer | Post-task scribe. |
| `sentinel-fetcher` | haiku | PR diff/comment fetcher | Pattern 5 (research isolation). Async fire-and-forget. Haiku is correct here. |
| `sentinel-scribe` | sonnet | Sentinel wiki maintainer | Post-task scribe. |
| `orchestrator` | opus | Multi-step build coordinator | Pattern 3 + 4 hybrid. Drives plan → implement → test → review → commit with explicit gates. **The one place orchestration depth > 1 is intentional** — but stays bounded by the cycle cap. |
| `architect` | opus | Architecture/system design specialist | Pattern 1 direct invocation, or Pattern 5 (read-only design study). |
| `researcher` | sonnet | Codebase research for orchestrator | Pattern 5 — read-only digest producer. Sonnet sufficient; output is structured findings, not synthesis. |
| `implementer` | sonnet | Targeted edit-only implementer | Pattern 4 step. Receives plan + research, makes minimal diffs. Sonnet sufficient — no synthesis. |
| `tester` | opus | Test enforcer + green-loop runner | Pattern 4 step. Opus to handle gnarly test-failure root-causing. |
| `debugger` | sonnet | Error / test-failure triage | Pattern 1 direct invocation. **Watch:** debugging often needs frontier reasoning; promote to opus if it shows symptom-vs-cause failures. |
| `senior-qa` | sonnet | Black-box application testing | Pattern 1 direct. |
| `context-manager` | opus | Multi-agent state management | Pattern 3 support. |
| `Explore`, `Plan` | (built-in haiku) | Built-in research subagents | Pattern 5. Use these before defining a custom research persona. |

### Model discipline (cascade peer gate)

Pattern 3 (parallel fan-out + synthesizer) only works if every peer is frontier-class. A weak peer produces shallow findings the synthesizer cannot recover — the cascade silently degrades.

**Gate** (enforced at agent definition time, not runtime):

- Every Pattern 3 peer MUST set `model:` ≥ the synthesizer's tier. If sentinel is opus, every peer must be opus.
- Pattern 5 (research isolation) MAY use haiku — fetchers consume large input and return small digests, so reasoning depth matters less than throughput. Haiku is correct for `voltage-fetcher`, `sentinel-fetcher`, and built-in `Explore`.
- Pattern 4 (sequential pipeline) steps MAY mix tiers — each step is a single perspective, not a peer-merge. Sonnet is acceptable for `implementer` (edit-only), `researcher` (digest), `senior-qa` (black-box). Promote to opus only if symptom-vs-cause failures recur.
- Scribes (`*-scribe`) are sonnet by design — wiki maintenance is mechanical.

**Audit (2026-05-08):** Every sentinel cascade peer (`architect-review`, `ai-architect`, `spock`) is on opus. Synthesizer (`sentinel`) on opus. Gate satisfied. Re-audit when adding any cascade peer.

**Watch list:**
- `debugger` is sonnet. Debugging often benefits from frontier reasoning; promote to opus if recurring symptom-vs-cause regressions appear.
- Adding any new opus-cascade peer must come with an explicit model-tier justification in this appendix.

### Cascade clarification (sentinel ≠ Anti-pattern B)

Sentinel calling spock + architect-reviewer + ai-architect *looks* like Anti-pattern B (persona-calls-persona) but is Pattern 3 (parallel fan-out with synthesizer):

- Peers run **in parallel**, not chained
- Sentinel **synthesizes** all peer outputs into one verdict — peers don't synthesize each other
- The cascade is **cycle-bounded** (3-cycle cap, severity gating after cycle 1, finding-velocity convergence)
- Each peer has a **distinct lens** (DevSecOps / architecture / AI-impact / cross-vendor) — not redundant perspectives

If a future agent's cascade lacks a synthesizer, parallel execution, or convergence bounds, it's Anti-pattern B — refactor to Pattern 2 + user-driven follow-up.

### When to reach for Agent Teams

Currently no production use. Reserve for competing-hypothesis debugging where teammates need to message each other (e.g. intermittent prod issue with multiple plausible root causes). For verdict on a known artifact, stick with sentinel's cascade.

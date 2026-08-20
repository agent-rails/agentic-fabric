# Architecture

How the stack is put together and how a request moves through it. For *why* each choice was made, see [DESIGN-PRINCIPLES.md](DESIGN-PRINCIPLES.md) and [decisions/](decisions/).

## The one-paragraph version

This is a personal multi-agent stack layered on top of Claude Code. Work is done by **personas** (agent definitions in `agents/`), triggered either directly or through **slash commands** (`skills/`, `commands/`). Personas read from and write back to **wikis** — persistent, git-backed markdown memory that survives across sessions. **Hooks** (`scripts/`) enforce the rules that must never be skipped, at the tool-call layer rather than in a prompt. **Rules** (`rules/`) and a small **shared-wiki** carry the cross-cutting facts and conventions every persona obeys. The user is the orchestrator; personas produce a single perspective and hand back.

## Component map

Model tiers: (o) opus, (s) sonnet, (h) haiku.

```mermaid
flowchart TD
    user["USER<br/>(orchestrator, see ADR-0002)"]
    harness["CLAUDE CODE HARNESS<br/>rules/ . hooks (scripts/) . shared-wiki"]
    user -->|"direct call / slash command"| harness

    subgraph your-triage-agent["your-triage-agent family (comms / chief-of-staff)"]
        v["your-triage-agent (o)"]
        vf["your-triage-fetcher (h)"]
        vs["your-triage-scribe (s)"]
        vr["your-triage-reporter (s)"]
        v --> vf
        v --> vs
        v --> vr
    end

    subgraph your-pr-reviewer["your-pr-reviewer family (PR review / institutional memory)"]
        s["your-pr-reviewer (o)"]
        sf["your-pr-review-fetcher (h)"]
        ss["your-pr-review-scribe (s)"]
        ar["architect-review (o)"]
        aa["ai-architect (o)"]
        sp["your-cross-vendor-reviewer (o, x-vendor)"]
        sv["your-same-vendor-reviewer (o, same-vendor fallback)"]
        sc["your-patch-drafter (o, x-vendor)"]
        s --> sf
        s --> ss
        s -.cascade peers.-> ar
        s -.cascade peers.-> aa
        s -.cascade peers.-> sp
        sp -.unavailable? fallback.-> sv
        s -.fix drafts.-> sc
    end

    harness --> your-triage-agent
    harness --> your-pr-reviewer

    vwiki[("~/your-triage-agent/wiki<br/>people, channels, pending, reports")]
    swiki[("~/your-pr-reviewer/wiki<br/>repos, authors, patterns, reviews")]
    your-triage-agent <--> vwiki
    your-pr-reviewer <--> swiki

    build["build/QA roles (cross-cutting):<br/>orchestrator, researcher, implementer,<br/>tester, debugger, architect, senior-qa, context-manager"]
    harness --> build
```

## The five layers

### 1. Personas — `agents/`

Each `agents/*.md` is a system prompt with frontmatter (name, description, model, tools). A persona is one perspective on one kind of work. Two families plus a set of build/QA roles:

- **your-triage-agent** — chief-of-staff. Triages email/Slack/LINE/Messenger/calendar into four tiers, drafts replies from wiki relationship context, enforces post-send follow-through. Subagents: `your-triage-fetcher` (per-channel pull, haiku), `your-triage-scribe` (wiki writes, sonnet), `your-triage-reporter` (daily/weekly reports, sonnet).
- **your-pr-reviewer** — PR-review synthesizer with a DevSecOps lens. Reviews diffs, calibrates severity against evidence, tracks repo/author patterns. Subagents: `your-pr-review-fetcher` (haiku), `your-pr-review-scribe` (sonnet), and the cascade peers `architect-review`, `ai-architect`, `your-cross-vendor-reviewer` (cross-vendor, falls back to `your-same-vendor-reviewer` when no second vendor is reachable), plus `your-patch-drafter` (cross-vendor patch drafter).
- **build/QA roles** — `orchestrator`, `researcher`, `implementer`, `tester`, `debugger`, `architect`, `senior-qa`, `context-manager`. General software work, not tied to a family.

Model tiering is deliberate — judgment on opus, mechanics on haiku/sonnet. See [ADR-0001](decisions/0001-model-tiering.md).

### 2. Triggers — `skills/` and `commands/`

- `skills/*/SKILL.md` — slash-command workflows: `/triage`, `/review-pr`, `/draft-pr-fixes`, `/daily-report`, `/standup`, `/self-review`, `/pr-sizer`, `/workflow-miner`, and more. A skill is a saved, versioned prompt that wraps a persona with the right setup so the user doesn't re-explain it every time.
- `commands/` — older-style command prompts kept for continuity.

A slash command is the orchestration layer. It does not add a routing persona; it *is* the route. See [ADR-0002](decisions/0002-user-is-orchestrator.md).

### 3. Memory — `wikis/`, `shared-wiki/`

Persistent, git-backed markdown. Every session reads relevant pages before acting and writes back after.

- **Agent wikis** (`~/your-triage-agent/`, `~/your-pr-reviewer/`) — domain memory. People, channels, pending items, reports (your-triage-agent); repos, authors, patterns, review log (your-pr-reviewer). This repo ships only the *machinery* (`wikis/your-triage-agent/`, `wikis/your-pr-reviewer/`: purpose, schema, templates, helper scripts). The *data* fills itself through use and is deliberately excluded.
- **shared-wiki** (`~/.claude/shared-wiki/`) — the small cross-cutting fact layer read by every agent on every invocation: `agent-principles.md`, `search-discipline.md`, `orchestration-patterns.md`, plus entity pages (user, people, repos, projects). Kept to ~3-9 pages by an explicit promotion gate.

Wiki-as-memory is the spine of the whole design. See [ADR-0003](decisions/0003-wiki-as-memory.md).

### 4. Enforcement — `scripts/` (hooks)

PreToolUse / PostToolUse hooks wired into `~/.claude/settings.json` (template in `docs/settings.hooks.example.json`). They fire on Claude tool calls at the harness level, so the LLM cannot forget or route around them:

- `enforce-branch-prefix.sh` — blocks agent-created branches that aren't `<alias>/`.
- `gh-pr-create-gate.sh` — blocks `gh pr create` without `--draft` (review-first workflow).
- `protect-gate-pages.sh` — blocks edits to the review-rubric / shared-wiki pages unless a fresh human unlock marker exists (verifier-immutability).
- `scan-skill.sh` — skill scanner.
- `scan-write-content.sh` — pre-write malicious-content scan, evaluated through [agent-guard](https://github.com/agent-rails/agent-guard)'s deterministic policy engine (`policies/write-content-scan.yaml`) rather than a second bespoke pattern-matcher. Optional — see README's Prerequisites.

Hooks over prompts is a first-class principle — an LLM ignores an instruction ~20% of the time; a hook is deterministic. See [ADR-0004](decisions/0004-hooks-over-prompts.md).

### 5. Conventions — `rules/`

Global rules files (general, git, planning, prompting, python, typescript, testing) injected as instructions. They govern coding style, commit discipline, planning cadence, and prompt authoring across every persona.

## Control flow — two worked examples

### Triage (`/triage` → your-triage-agent)

```
user → /triage → your-triage-agent (opus)
  1. read shared-wiki (identity, people, projects) + your-triage-agent wiki (patterns, channels)
  2. fetch: 3+ channels → fan out to your-triage-fetcher (haiku, one per channel, Pattern 5)
           single channel → inline tool call, no subagent
  3. classify each message → 4 tiers (skip/info_only/meeting_info/action_required)
     + routing verdict (auto_digest/team_feed/surface) in shadow mode
  4. draft replies for action_required using wiki tone + relationship context
  5. present drafts with [Send] [Edit] [Skip] — sending is a human gate (ADR-0006)
  6. after send → your-triage-scribe (sonnet): update people/pending/log, commit
```

```mermaid
sequenceDiagram
    actor User
    participant V as your-triage-agent (o)
    participant F as your-triage-fetcher (h)
    participant Sc as your-triage-scribe (s)
    participant W as ~/your-triage-agent/wiki

    User->>V: /triage
    V->>W: read shared-wiki + patterns/channels
    V->>F: fan out per channel (3+ channels, Pattern 5)
    F-->>V: message digests
    Note over V: classify 4 tiers + routing verdict (shadow)
    Note over V: draft replies from wiki tone + context
    V->>User: drafts [Send] [Edit] [Skip]
    User->>V: Send (human gate, ADR-0006)
    V->>Sc: hand off write-back
    Sc->>W: update people/pending/log + commit
```

Fetch fans out (research isolation), the model does the judgment (classify + draft), the scribe does the mechanical write-back. Cheap models on the ends, opus in the middle.

### PR review (`/review-pr` → your-pr-reviewer cascade)

```
user → /review-pr <url> → your-pr-reviewer (opus, synthesizer)
  1. Step 0 — necessity check: should this PR exist in this shape at all?
  2. your-pr-review-fetcher (haiku) pulls diff, changed files, existing comments
  3. on security/architectural/AI-impact paths, fan out IN PARALLEL (Pattern 3):
       ├ architect-review (opus)   — architectural consistency
       ├ ai-architect (opus)       — LLM/agent-impact concerns
       └ your-cross-vendor-reviewer (opus, codex-backed) — cross-vendor reasoning diversity
  4. your-pr-reviewer SYNTHESIZES all peer outputs into one verdict
     — evidence-calibrated severity (unverified BLOCKERs get downgraded)
     — cycle-bounded: 3-cycle cap, severity gating after cycle 1, convergence detection
  5. your-pr-review-scribe (sonnet) updates repo/author/pattern pages + review log
  6. optional follow-up: user runs /draft-pr-fixes → your-patch-drafter drafts patches (never applies)
```

```mermaid
sequenceDiagram
    actor User
    participant S as your-pr-reviewer (o, synthesizer)
    participant F as your-pr-review-fetcher (h)
    participant AR as architect-review (o)
    participant AA as ai-architect (o)
    participant SP as your-cross-vendor-reviewer (o, x-vendor)
    participant Sc as your-pr-review-scribe (s)

    User->>S: /review-pr <url>
    Note over S: Step 0 - necessity check
    S->>F: pull diff, files, comments
    F-->>S: PR data
    Note over S: security/arch/AI path? fan out in parallel (Pattern 3)
    par parallel peers
        S->>AR: architectural consistency
        S->>AA: LLM/agent-impact
        S->>SP: cross-vendor diversity
    end
    AR-->>S: findings
    AA-->>S: findings
    SP-->>S: findings
    Note over S: synthesize one verdict<br/>evidence-calibrated severity<br/>cycle-bounded (3-cap, gating, convergence)
    S->>User: verdict
    S->>Sc: hand off write-back
    Sc->>S: repo/author/pattern pages + review log updated
    Note over User: optional: /draft-pr-fixes -> your-patch-drafter drafts (never applies)
```

The cascade is the one place fan-out happens, and it is strictly bounded — parallel peers, one synthesizer, a cycle cap. This is Pattern 3, not persona-calls-persona. See [ADR-0005](decisions/0005-cross-vendor-cascade.md) and the [orchestration-patterns catalog](../shared-wiki/orchestration-patterns.md).

**Same-vendor fallback, not shown in the diagram above for clarity:** if `your-cross-vendor-reviewer` returns `verdict: unavailable` (most commonly no second-vendor CLI installed), the orchestrator spawns `your-same-vendor-reviewer` in its place — same review modes, same evidence-calibration contract, but explicitly self-labeled `cross_vendor: false` throughout. your-pr-reviewer's synthesis tags its findings `(your-same-vendor-reviewer same-vendor)`, never `(cross-vendor)`, and the verdict header states plainly that cross-vendor review specifically did not run. This keeps a fresh adversarial second pass in the loop even with zero second-vendor tooling installed, without ever presenting it as vendor-diversity it isn't.

## Why families, not one mega-agent

your-triage-agent and your-pr-reviewer share the same skeleton — opus lead, haiku fetcher, sonnet scribe, git-backed wiki — but stay separate because they answer different questions and their memory would drift if merged. A person's triage history and a repo's review history are different surfaces with different decay rates. Shared-wiki carries only the facts *both* need; everything else stays domain-local. This is the promotion/demotion discipline described in `shared-wiki/purpose.md`.

## The orchestration constraint

The whole design leans on orchestration depth staying at most 1: slash command → personas → synthesis in one designated agent, with a single intentional exception (the `orchestrator` agent for multi-step builds, bounded by the cascade cycle cap). This is a **prompt-level constraint, not a platform guarantee.** An earlier version of this document claimed Claude Code made nested subagent spawning "impossible by construction"; that is empirically false — subagents *can* spawn subagents, observed directly. The dangerous anti-patterns (router personas, deep persona trees, persona-calls-persona chains) are held off by convention, review, and the pattern catalog, not by the harness refusing to load them. See [ADR-0010](decisions/0010-orchestrator-depth-gate.md) for why this gap is accepted rather than mechanized. The full catalog of endorsed patterns and anti-patterns lives in [orchestration-patterns.md](../shared-wiki/orchestration-patterns.md).

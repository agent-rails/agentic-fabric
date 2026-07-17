# workflow-miner schemas

## Candidate entry

`workflow-candidates.md` is a markdown file with one section per stage.
Each row of the per-stage table has these columns:

| Field | Type | Notes |
|-------|------|-------|
| id | string | deterministic hash — see Determinism rules |
| pattern | string | one-line summary |
| trigger | string | time/event trigger if detected |
| steps | list | ordered task references |
| frequency | int | distinct calendar dates in window — see Determinism rules |
| evidence | list | `path#section-or-date` refs (one per occurrence) |
| existing_skill | string \| null | matching skill name — see Existing-skill matching |
| token_savings_kb | float | estimated per-invocation savings — see Token savings estimation |
| stability | float | 1.0 / 0.7 / 0.5 — see Scoring |
| score | float | computed final score |
| stage | enum | `skill_candidate` / `skill_drafted` / `skill_proven` / `cron_eligible` / `dormant` |
| first_seen | date | first occurrence date in window |
| last_seen | date | last occurrence date in window |

## Tracking entry

`workflow-tracking.md` is the durable state file. Persists across runs.
Empty on first run; leave empty until a candidate has been promoted past stage 1.

| Field | Type | Notes |
|-------|------|-------|
| skill | string | skill name |
| candidate_id | string | links to candidate row |
| invocations | int | count since drafting |
| last_invoked | date | last invocation observed |
| content_hash_at_drafting | string | sha256 of SKILL.md content captured at `skill_drafted` transition |
| stage_advanced_at | date | when current stage was reached |
| current_stage | enum | mirrors candidate stage |

## Determinism rules

Two re-runs over the same window must produce identical `id`s and `frequency`s.

### `id` hash

```
id = "wf-" + sha1(normalize(steps)).hexdigest()[:12]
normalize(steps) = "|".join(s.strip().lower() for s in steps)
```

- Hash function: SHA1 (pinned; do not substitute)
- Truncation: 12 hex chars
- Prefix: `wf-` (literal)
- Normalization: lowercase, strip whitespace, join with `|`
- Step list order matters — different order = different id

### `frequency` collapsing

`frequency` = count of distinct calendar dates (YYYY-MM-DD) on which the
pattern occurred in the window. Multiple occurrences on a single date
count as 1.

- Use the date as it appears in the evidence source (file date, log row date)
- No timezone conversion — trust the recorded date
- A batch of 3 PRs on 2026-05-04 for the same pattern = frequency contribution of 1

### `evidence` ordering

Sort evidence list ascending by date, ties broken by source path lexically.
Same input → same output ordering.

## Scoring

```
final_score = frequency * stability * log(1 + token_savings_kb)
```

Stability tiers:
- 1.0 — recurring scheduled: same time-of-day +/-1h on same weekday across occurrences
- 0.7 — recurring same weekday: same weekday, varying time
- 0.5 — event-driven: no detectable cadence (default for reactive DevOps work)

Stability is a tier choice, not a continuous value. Pick the highest tier
whose criteria are met.

Ranking is for surfacing top-5; not a transition criterion.

## Token savings estimation

```
token_savings_kb = n_steps * 1.2 + 1.5
```

- `n_steps`: number of steps in the candidate
- `1.2 KB/step`: avg cost to re-derive each step from context per ad-hoc invocation
- `1.5 KB`: baseline overhead per ad-hoc invocation (clarification, lookup)

This is an estimation rubric, not a measurement. Document overrides in
the candidate row only when a step has unusual cost (e.g., requires reading
a 20+ KB file to execute) — note it in the `pattern` field, not as a
formula override. The formula stays fixed for reproducibility.

## Existing-skill matching

For each candidate, read frontmatter `description` from every
`~/.claude/skills/*/SKILL.md` and `~/.claude/agents/*.md`. The mining agent
judges semantic match — if the candidate pattern is already covered by an
existing skill or agent, set `existing_skill` to that name.

- Match must be substantive (covers the same workflow), not topical (mentions the same domain)
- Partial overlap → set `existing_skill` to the closest match AND note the gap in `pattern`
  (e.g., "extends `triage` with MCP-vuln cross-posting")
- No match → `existing_skill: null`

Lexical-only matching (directory name) is insufficient. Reading descriptions
is the spec.

## Stage transitions

| From | To | Required |
|------|-----|----------|
| (none) | `skill_candidate` | freq >= 3 AND no matching existing skill |
| `skill_candidate` | `skill_drafted` | user approves AND skill file exists at `~/.claude/skills/<name>/SKILL.md` AND `content_hash_at_drafting` captured in tracking |
| `skill_drafted` | `skill_proven` | invocations >= 5 AND age >= 14d AND current sha256(SKILL.md) == `content_hash_at_drafting` |
| `skill_proven` | `cron_eligible` | user explicitly approves cron promotion |
| `skill_proven` | `dormant` | last_invoked > 30d ago |
| `cron_eligible` | `dormant` | last fired > 60d ago |
| `dormant` | (deletion) | user approves removal |

No transition is automatic. Each one requires either an explicit user
signal recorded in `workflow-tracking.md` or an observed time/hash threshold.

Content-hash check (not mtime) for the unedited gate — robust against
touch / rsync / checkout that bump mtime without changing content.

## Edge handling principle

Trust the inside; fail loud at the edge.

- Inside the pipeline: no defensive try/except around parsing, hashing, or
  scoring. Defensive capture inside is a bug source — surface the failure.
- At the source-read boundary: missing source file or unreadable path -> halt
  with explicit error naming the path. Sources are: daily reports dir,
  voltage log, sentinel log, skills dir, agents dir.
- At the output-write boundary: output files at `~/voltage/wiki/recurring/`
  MAY be missing on first run; create them. Halting on missing output files
  would block bootstrap.
- At the schema boundary: malformed candidate JSON, unknown stage, missing
  required field -> halt; do not write partial state.

## Idempotency

- Re-running `/workflow-miner` on the same window must produce identical
  `id`s, `frequency`s, and evidence ordering (deterministic by spec)
- Stage advancements only fire when the gate criterion newly resolves true;
  the timestamp is captured in `stage_advanced_at` to prevent re-counting
- `content_hash_at_drafting` is written once at `skill_drafted` and never
  rewritten until the skill is re-drafted (stage demotion + redraft)

## Token budget

| Resource | Cost |
|----------|------|
| Subagent invocation | 1 call |
| Source read | ~50-80 KB across logs, reports, skill descriptions |
| Output write | 2 files, ~5-15 KB each |
| Per-turn overhead | 0 |

## Invocation log

Skill invocations are captured by a `PreToolUse` hook with matcher `Skill`,
configured in `~/.claude/settings.json`. The hook script at
`~/voltage/scripts/log-skill-invocation.sh` appends one JSON line per
invocation to `~/voltage/wiki/recurring/.invocations.jsonl`:

```json
{"timestamp":"2026-05-05T18:23:14Z","skill":"workflow-miner"}
```

Schema:
- `timestamp`: UTC ISO8601 (`%Y-%m-%dT%H:%M:%SZ`)
- `skill`: the skill name from `tool_input.skill`

The miner aggregates this log each run:
- `invocations` column = count of JSONL entries per skill
- `last_invoked` column = max(timestamp) per skill

The JSONL is append-only; the miner never truncates it. If file size
becomes an issue (>1MB), rotate manually — the miner re-aggregates from
whatever lines remain.

Edge handling:
- Missing JSONL file → 0 invocations for all skills (first-run case)
- Malformed JSONL line → skip that line; do not halt
- Skill name not in tracking.md → ignore (untracked skill, no row to update)

## Orchestration manifest

Promoted candidates (stage 2+) get a row in
`~/voltage/wiki/recurring/orchestration.md` mapping the skill to its
trigger type (manual / schedule / hook / agent). The manifest is the
single source of truth for orchestration state, decoupled from skill
files — skills stay capability-only; trigger config is data.

This skill never writes the manifest directly. Promotion to stage 2+ is
the user's signal to update it; demotion to dormant is the signal to
disable the underlying primitive (cron entry, hook, agent).

## Non-goals

- Mining transcript history (too heavy, privacy-sensitive)
- Real-time pattern detection (batch only)
- Auto-creating skill files (proposal only — user runs `skill-management`)
- Auto-creating cron triggers (proposal only — user runs `schedule`)
- Auto-writing the orchestration manifest (user-driven at promotion time)
- Promoting candidates without an explicit user signal recorded in tracking

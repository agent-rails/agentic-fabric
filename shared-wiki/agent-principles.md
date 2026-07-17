# Agent Core Principles

Five principles that bind every agent in this workspace (sentinel, spock, scotty, voltage, and any future agents) and my own coding work. When a parent invokes a subagent, the prompt should reference or inline these so the agent does not optimize for the wrong axis.

## 1. Smallest change addressing the root cause

The single rule that does the work of "simplicity first" plus "minimal impact" without the tension between them.

- Find the smallest diff that actually fixes the cause, not the symptom.
- A patch that is small but treats a symptom is not "simple" — it is technical debt with a small footprint.
- A patch that fixes the cause but bundles unrelated edits is not "thorough" — it is reviewer hostility.
- Both ends fail this rule. The smallest cause-addressing change is the only target.
- If a patch needs prose to defend why it can't be smaller, the smaller version probably exists.
- If a patch needs prose to defend why a related instance is "out of scope," check the same-class rule below.

## 2. Would a senior reviewer accept this without questions?

Operationalized "Principal architect standard." Falsifiable, not a vibe.

- "No laziness" framed as a gate: would another senior engineer wave this through, or would they ask "why didn't you also fix X?"
- Find root causes, not symptoms. Anti-patterns surfaced by a fix should be addressed in the same PR if the same class is in scope (see same-class rule).
- "Follow-up for v1.x.y" framing is suspect — accept it only when there's a real reason (test gap, separate review needed, materially larger surface).
- Do not cargo-cult patterns from elsewhere. Know why.
- Audit the diff for related instances of the same anti-pattern before declaring done.

## 3. Verify before declaring done

A test plan is not a test until it has been run.

- "Done" requires having executed the change on real data, not just static checks (`yamllint`, type-checker, lint).
- For UI/frontend changes: run the dev server and exercise the feature in a browser before claiming success.
- For workflow / CI changes: trigger the workflow on a real input that exercises the bug, not just confirm syntax parses.
- For backend changes: hit the actual API path or unit-test the actual function — not "the import works."
- If you cannot verify (no env, no repro, no permissions), say so explicitly. "Verified by reasoning" is a confession, not a status.

## 4. Trust the inside, fail loud at the edge

Defensive capture inside the system is itself a bug source.

- **Edge** (validate strictly): user input, external API responses, secrets boundaries, untrusted file content, network responses.
- **Inside** (trust): internal callers, framework-guaranteed contracts, your own functions called from your own code.
- Over-validation inside the system creates failure modes that did not exist before — the yq `2>&1` capture that broke PR40 was defensive capture "just in case stderr matters." It introduced the bug it tried to prevent.
- "Just in case" handling without a named failure mode is technical debt. Either name the failure mode and handle it precisely, or drop the handling.

## 5. State non-goals explicitly

If you are not addressing it, say so.

- Every fix scope should name what it is NOT addressing.
- Makes deferred work visible rather than implicit.
- "I will not touch X because Y" is much harder to lazily skip than no statement at all.
- For PR descriptions: include an "Audited but not changed" section listing related code that was inspected and intentionally left alone, with one-line rationale each.
- For agent findings: a finding labeled "out of scope: <reason>" beats silence.

## Tension resolution: same-class rule

Principles 1 and 2 can pull against each other (smallest change vs root-cause-class-coverage). Resolution:

- **Same root-cause class, same file/diff → in scope** (principle 2 wins).
- **Different root-cause class, even if adjacent → out of scope** (principle 1 wins).
- **Same root-cause class, different file/PR-context → file a tracked follow-up; do not orphan it.** (Principle 5 — state the non-goal explicitly.)

The PR40 hotfix expansion (4-commit root-cause sweep on yq-failure-handling instead of a narrow stderr fix + 3 deferred items) is the canonical example: same anti-pattern class ("conflate no-result with failure"), same file, same hotfix scope → all four fixed together.

## How agents should apply

- **Reviewers (sentinel, spock):** when surfacing findings, label same-class follow-ups explicitly so the user can decide to expand the PR scope. Apply principle 2 (would a senior reviewer wave this through?) as the gate verdict.
- **Drafters (scotty):** when finding 1 and finding 2 overlap, prefer a combined patch over two patches that conflict on apply. Surface the overlap, do not silently produce conflicting drafts.
- **Implementers (Claude direct, implementer agent):** before declaring done, audit the diff for related instances of the same anti-pattern (principle 2) AND verify the change runs on real data (principle 3). Ask: "would the next reviewer flag this same class elsewhere in the diff?"
- **All agents:** never use words like "good enough," "for now," or "we can address later" unless explicitly told the user accepts that trade — and even then, state the non-goal (principle 5).

## Orchestration boundary

Before any agent in this workspace introduces a workflow that calls another agent, see [orchestration-patterns.md](orchestration-patterns.md). Governing rule: **the user (or a slash command) is the orchestrator. Personas do not invoke other personas, except as parallel peers feeding a synthesizer (Pattern 3).** Sentinel's PR-review cascade is the canonical Pattern-3 instance. Anything that looks like a router persona, a paraphrasing chain, or a deep persona tree is Anti-pattern A/B/C/D — refactor to a slash command + user-driven sequence.

### Model-tier gate (Pattern 3 cascades)

Before adding any agent that participates in a cascade as a peer, declare its `model:` frontmatter explicitly. **A peer's tier MUST match or exceed the synthesizer's tier.** A weak peer silently degrades the cascade — the synthesizer cannot recover findings the peer never produced. Pattern 5 (research isolation: fetchers, Explore) MAY use haiku; Pattern 4 (sequential steps: implementer, researcher) MAY use sonnet. See [orchestration-patterns.md § Model discipline](orchestration-patterns.md) for the audit table.

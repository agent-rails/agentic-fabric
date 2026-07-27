# Cascade Default Policy

**Status**: active since 2026-05-11
**Owner**: review-pr workflow
**Decision**: option 2 from cascade-policy proposal — cross-vendor-reviewer-by-default with narrow skip rule

## Policy

`cross-vendor-reviewer` (cross-vendor codex-backed reviewer) cascades on **every PR review by default**. The orchestrator spawns pr-reviewer + cross-vendor-reviewer as peers and passes cross-vendor-reviewer's output to pr-reviewer for synthesis.

### Skip rule

Skip the cross-vendor-reviewer cascade only when ALL three conditions hold:

1. **Docs-only diff** — every changed file matches one of: `*.md`, `docs/**`, README, comments-only changes inside source files
2. **Diff size < 100 LOC** — total `additions + deletions` from `gh pr view {n} --json files`
3. **No file in any of these paths** is touched:
   - `.github/workflows/**`, `.github/actions/**`, `actions/**`
   - `**/Dockerfile`, `**/Containerfile`
   - `**/terraform/**`, `**/helm/**`, `**/k8s/**`, `**/argocd/**`, `**/applicationsets/**`
   - any path in the always-cascade list below

### Always cascade (no skip override)

The Security-Critical Path Filter list from `agents/pr-reviewer.md` — auth, hooks, secrets, IAM, prod IaC, classifier engine, threat-model docs. The skip rule does NOT override these. If a docs PR amends `docs/security/*-RFC.md` it still cascades.

## Why

Two concrete misses justified the flip from path-gated to default-on:

- **PR #49 cycle-2** surfaced 3 BLOCKERs + 5 HIGHs that single-reviewer cycle-1 missed. Root cause: cycle-1 declared closed without cross-vendor validation. See `anti-patterns/cycle-1-review-declares-closed-without-cross-vendor-validation`.
- **PR #52 cycle-1** missed 1 BLOCKER (description vs code asymmetry on `configure-ecr-credentials` extraction) and 1 HIGH (missing fork-PR guard on manifest job with `id-token: write`) that cross-vendor caught. Different model family reads PR description against diff and notices assertions the code doesn't support.

Counter-pressure exists: `anti-patterns/cross-vendor-cascade-overreach-on-docs-spec-prs` shows over-cascading on trivial docs PRs creates calibration noise (PR #84 had 6/9 cycle-1 findings declined fairly on re-walk). The skip rule narrowly excludes the trivial-diff case where overreach is the real risk.

## Tradeoffs

- **Cost**: roughly doubles review time per non-trivial PR (~4min → ~8min) and tokens per review.
- **Catch-rate**: catches cross-vendor-unique findings that single-vendor cycles systematically miss — most valuable on security-critical paths but also valuable on novel surfaces (OIDC chains, agentic orchestration, eval pipelines).
- **Calibration**: skip rule prevents the overreach anti-pattern on docs / trivial diffs.

## How the orchestrator applies this

1. Fetch `gh pr view {n} --json files,additions,deletions` (already part of grounding).
2. Evaluate skip rule against the file list and total LOC.
3. If skip rule does **not** apply → spawn pr-reviewer + cross-vendor-reviewer as peers; pass cross-vendor-reviewer output to pr-reviewer for synthesis.
4. If skip rule **does** apply → spawn pr-reviewer only.
5. Respect existing path filters for architect-reviewer and ai-architect per their own triggers.

## Anti-carve-out: re-reviews on small focused diffs do NOT qualify for cascade skip

The skip rule above covers trivial docs-only content. It does NOT cover re-reviews of fix commits — even small, scope-bounded ones that address already-agreed findings. This carve-out seems appealing ("the diff is tiny and addresses exactly what was flagged") but is not safe. The reason is structural:

> A re-review focused on already-agreed findings **narrows reviewer attention to those items**. Adjacent surfaces — logically related but not in the fix commits — are naturally de-prioritized. Cross-vendor diversity is most valuable precisely when first-vendor attention is narrowed.

This is the same dynamic as convergence-review-new-content-gap ([[anti-patterns/convergence-review-new-content-gap]]) but applied to re-review scope rather than new content sections.

### Concrete example: monitoring-checks#412 cycle 2 (2026-06-08)

| Field | Detail |
|-------|--------|
| PR | your-org/monitoring-checks#412 |
| Cycle 1 | In-house + cross-vendor cascade. Verdict: REQUEST_CHANGES. 1 BLOCKER (thirdParty precedence not implemented), 2 HIGH (unknown-key validation; hardcoded failedRunThreshold), 3 MEDIUM, 1 LOW. Review <review-id-1>. |
| Cycle 2 head | `<sha-2>` (fix commits `<sha-1>` + `<sha-2>`). Author addressed 4 findings, pushed back on 3. |
| Cascade decision | **Skipped** — judgment was "small focused diff addressing already-agreed findings." Posted APPROVE (review <review-id-2>). |
| Backstop (post-approval) | User ran cross-vendor backstop. Found 1 MEDIUM + 1 nice-to-have pr-reviewer missed. |
| Miss | `thirdParty` per-env override key precedence for 3rd-party templates is undocumented in JSDoc and README (only an internal monitoring guide documents it). A caller using an unknown key against a URL-monitor template gets no error and the value is silently discarded — typed-valid key, value silently ignored. Same footgun class as cycle-1's unknown-key validation HIGH, one layer up. Filed as follow-up comment (issue #<comment-id>). |
| Root cause | Cycle-2 focus on the four addressed findings narrowed attention away from the adjacent documentation surface. Cross-vendor lens independently re-walked the template contract and caught the gap. |

The miss was ~4 lines of doc. But the class of miss — "scope focus creates adjacent-surface blindness" — justifies the policy: **no cascade skip on re-reviews, regardless of diff size or scope-boundedness**.

### Rule (amended)

The skip rule in § Skip rule above applies to **content class** (docs-only, small, no security-critical paths). It does NOT apply to **review cycle**. A cycle-2 re-review on 50-line fix commits that touch TypeScript helpers **is not a docs-only diff** and does not qualify for the docs-only skip.

When in doubt: if the diff touches any source, configuration, or template file — cascade.

## Considered carve-out (rejected — single data point): docs-as-infra-template

A natural extension of the letter-vs-spirit debate: should the skip rule exclude **docs that ARE infra templates**? A SKILL.md file is markdown, but if its content is a YAML workflow snippet that every future onboarding copies into a real `.github/workflows/deploy-dev.yml`, the blast radius is downstream every onboarded repo — not the doc PR itself.

### Concrete test: ai-toolkit#139 (2026-06-10)

| Field | Detail |
|-------|--------|
| PR | your-org/ai-toolkit#139 |
| Diff | 1 file (`plugins/argocd-team-onboarding/skills/argocd-team-onboarding/SKILL.md`), +8/-1 |
| Skip-rule eval | All three conditions held (docs-only, <100 LOC, no critical paths). Cascade skipped. |
| In-house pass | 3 conditions: inverse-handler reference to non-templatized `deploy-on-merge.yml`; hardcoded `master` in canonical YAML while skill warns at L583 that default branch varies; failure-mode caveat factually wrong (`branches-ignore` does suppress filtered-branch runs). All source-quoted. |
| Backstop cross-vendor | **Concurred on all 3 in-house conditions. Zero net-new findings.** Added one reframe (the hardcoded-`master` is a *silent no-op on `main`-default repos*, sharper user-harm statement than "doc-internal inconsistency") — same finding, sharper framing. |
| Conclusion | Cross-vendor caught nothing in-house missed on this docs-as-infra-template PR. |

The carve-out hypothesis ("skill markdown drives downstream workflows, so cascade by default") is theoretically appealing but **not justified by evidence** as of 2026-06-10. One data point doesn't make a policy; this one says the in-house pass handles the failure modes (wording / cross-reference / contradiction) that this PR class produces.

### Rule (no change)

The skip rule stays as-is. Docs-only / <100 LOC / no critical paths qualifies for skip, regardless of whether the docs are infra templates.

Reopen this carve-out only if **future docs-as-infra-template PRs surface cross-vendor-unique findings the in-house pass missed**. Track via `feedback_cascade_growth` — if a second data point emerges, revisit.

## References

- `agents/pr-reviewer.md` § Cross-Vendor Cascade Default
- `skills/review-pr/SKILL.md` § Execution
- `anti-patterns/cycle-1-review-declares-closed-without-cross-vendor-validation`
- `anti-patterns/cross-vendor-cascade-overreach-on-docs-spec-prs`
- `anti-patterns/convergence-review-new-content-gap`
- `feedback_cascade_growth` memory rule (see also `feedback_cascade_growth` — "when external feedback catches a cascade miss, that's a missing lens")

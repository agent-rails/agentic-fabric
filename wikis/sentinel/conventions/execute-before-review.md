---
title: Execute before review — default to E2E, opt out on constraint
type: convention
status: active
---

## Principle

**Default to executing the diff as part of review, not just reading it.** Run unittests, `helm template`, `terragrunt plan`, the build, type checks, schema validation — whatever is testable end-to-end — BEFORE producing findings. Static reasoning misses bugs that runtime exposes (vacuous regex matches, nil-pointer panics on edge inputs, type-coercion drift, broken inner templates from raw interpolation).

The cost of execution is seconds-to-minutes. The cost of a missed bug surfacing two review cycles later is hours.

## Default: execute

By PR type, the minimum E2E pass before reviewing:

| PR type | Minimum execution |
|---|---|
| Helm chart | `helm lint`, `helm unittest` (if `tests/*_test.yaml` exists), `helm template` with edge-case `--set` flags |
| Terraform / Terragrunt | `terragrunt validate`, `terragrunt plan` (read-only, idempotent) |
| Python app | `pytest` (or test suite), `ruff check`, `mypy` / `pyright` |
| TypeScript app | `yarn test` (or test suite), `tsc --noEmit`, lint |
| Config (JSON / YAML) | Parse + schema validation if applicable |
| K8s manifests | `kubectl apply --dry-run=server` (against a non-prod cluster) if available |
| Docs only | Skip — nothing to execute |

For chart-specific edge cases, walk the [Helm / Go-template review checklist](./helm-template-review-checklist.md) (a focused subset of this principle).

## Opt-out: only with explicit constraint

The reviewer surfaces the opt-out reason in the review output. Acceptable constraints:

- **Egress / data sensitivity** — codex would see private content not approved for external review (spock's egress screen handles this automatically; document in the review if non-execution was due to egress).
- **Side effects** — apply / migration / state-mutating operations cannot run as part of review. ONLY read-only operations (`plan`, `validate`, `dry-run`, `template`) qualify as "executable."
- **Cost** — long CI runs (>10 min), cloud API spend. Weigh against bug-cost.
- **Tooling unavailable** — no local cluster for k8s integration, no codex CLI, etc.

"It might be slow" or "I assumed the test would pass" are NOT acceptable constraints.

## Where this gets enforced

- **Sentinel** (`agents/sentinel.md`) — Step 3 (Analyze) runs the relevant execute pass before producing own findings. If execution is skipped, surface the reason in the review header.
- **Spock** (`agents/spock.md`) — codex prompt includes "execute first" guidance; codex's sandbox supports `helm`, `terraform`, `terragrunt`, `pytest`, `yarn test` etc. in read-only mode.
- **Review-pr skill** (`skills/review-pr/SKILL.md`) — orchestrator-side step before spawning agents: detect testable surfaces in the diff, run them, include results in PR_PREFETCH.
- **Author** — before requesting review, run the same pass locally. The reviewer should not be the first to notice a failing test.

## Incidents this would have caught

- PR your-org/charts#73 cycle-3 (2026-05-21): 5 chart bugs, all surfaced in seconds by running `helm unittest` + `helm template --set X=null` / `--set-string X=False`. Static cross-vendor pass missed all 5. Human reviewer caught all 5 by executing.

## Anti-pattern this convention replaces

**"Read the diff, reason about it statically, produce findings."** That's the cycle 1 default. It works for architectural concerns (boundary, layering, contract), security concerns (secret hygiene, IAM over-grant), and known anti-patterns. It systematically misses runtime bugs.

Pair "read + reason" with "execute + verify." That's the new default.

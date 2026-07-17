# Operational Economics — Review Lens

A review lens that catches cost / billing / throughput / quota issues. Architecture, security, and AI/agent lenses don't have an operational-economics angle — this lens fills that gap.

## When to apply

Any change that touches:
- Reusable workflows fanned out to N consumers (cost compounds N-fold).
- Long-running jobs that sleep, poll, or wait indefinitely.
- Self-hosted runner pools with finite quota.
- Comment-triggered or webhook-triggered automation that can repeat-fire.
- Cron-driven jobs that may double-trigger or accumulate state.
- Any GHA workflow on a hosted runner with `timeout-minutes:` > 5.

## What to look for

| Smell | Why it hurts | Cheap test |
|-------|--------------|-----------|
| **Polling loops** (`while true; sleep 15`) on hosted runners | Billed for the full timeout duration even when waiting. 20-min poll × N concurrent triggers = compounding $. | Replace with `on: workflow_run` / `on: repository_dispatch` / registry webhook / ArgoCD hook. |
| **Long timeouts on shared-pool runners** | Self-hosted pool saturates; other jobs starve. GitLab-style "no new runners spun up" failure mode. | Lower timeout; or move to event-driven. |
| **Re-run multiplication** | One trigger condition that's over-broad runs N variants of an expensive job. | Tighten `paths:` filters; pin matrix dimensions; cancel-in-progress on superseded refs. |
| **No `concurrency: cancel-in-progress`** on push-triggered builds | Stacked builds for the same branch waste runner time on stale SHAs. | Add `concurrency:` block keyed by `github.ref`. |
| **Cancel-on-push fail-closed** for a deploy gate | Treats GitHub's standard auto-cancel of superseded builds as a gate failure → false negatives → user reruns → cost compounds. | Filter to latest run by `created_at`; non-superseded only. |
| **Repeated read of the same API surface** (no caching, no de-dup) in one workflow | Multiplies API quota use; on rate-limited APIs, multiplies wall-clock. | Stash to `$GITHUB_OUTPUT` once, reuse via `needs`. |
| **No early-exit when work is unnecessary** | Workflow runs to completion even when the trigger condition was a no-op. | Add an `if:` early-exit. |
| **Unnecessarily wide `paths:` triggers** | Workflow runs on file changes irrelevant to its purpose. | Narrow `paths:` to the actual surface. |

## Anti-patterns this lens catches

- `[[anti-patterns/polling-on-hosted-runner-billed-by-the-minute]]` (TBD)
- `[[anti-patterns/cancel-on-push-treated-as-fail]]`
- `[[anti-patterns/no-concurrency-cancel-in-progress-on-superseded-refs]]` (TBD)

## Reasoning prompt for reviewers

When applying this lens, ask:
1. **What is the runner-time cost per trigger?** Estimate worst case; multiply by expected trigger frequency.
2. **Is the trigger event-driven or polling?** If polling, why not event-driven?
3. **What happens under N concurrent triggers?** Does cost scale linearly or super-linearly?
4. **Where does the bill go?** Hosted runner minutes? API quota? Self-hosted pool saturation? Network egress?
5. **What does the alternative cost?** Webhook + handler is usually <30s of runner time vs N-minute poll loops.

If steps 1-4 don't yield clear answers, the design isn't ready.

## Related

- `[[conventions/templates-fan-out-versioning]]` — the cost-of-breaking-change angle, which compounds with this lens for templates.
- `[[patterns/cross-repo-gate-trust-on-publisher]]` — security companion lens.

## Why this exists

A real session reviewing `deploy-trigger-label.yml` produced an `approve_with_conditions` verdict from a 3-reviewer cascade (architecture + DevSecOps + cross-vendor). The design used a 20-minute polling loop. A senior engineer flagged the cost issue on Slack post-cascade — none of the agent lenses had caught it. Without this lens, the same blind spot recurs on every long-runner workflow review.

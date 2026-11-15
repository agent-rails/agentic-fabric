# Workflows

How changes made by agents get reviewed, how the review improves, and how to decide what to measure. Each page gives the goal, the steps, what enforces it today, the evidence with its tier, how it fails and how to adopt it.

| Workflow | Goal | Enforced by |
|---|---|---|
| [Review-first pull requests](review-first-pull-requests.md) | Nothing merges without a review of the commit that merges. | `fabric-gates` (draft-first create, merge gate, branch prefix, guardrail protection); reviewed-head matching is manual |
| [Cross-vendor review](cross-vendor-review.md) | A second model family reviews risky changes, within a 3-cycle cap. | Not yet enforced; manual |
| [Learn from escapes](learn-from-escapes.md) | Every escaped defect becomes an eval case the reviewer is tested on. | Not yet enforced; manual |
| [Measure before instrumenting](measure-before-instrumenting.md) | Act on the levers the logs show, and drop the ones that do not move. | Not yet enforced; manual |

Evidence tiers are explained in the [README](../README.md#evidence).

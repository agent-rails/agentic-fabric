# Patterns

What went wrong, and what worked, while running coding agents with hooks, reviewers and evals. Each page states the problem, when it applies, what to do, the evidence with its tier, and when it does not hold.

| Page | Problem | Kind | Evidence |
|---|---|---|---|
| [hook-fail-closed-without-onfailure](hook-fail-closed-without-onfailure.md) | A hook called fail-closed lets the call run when it crashes or times out. | anti-pattern | Reproduced; Observed |
| [global-hook-runs-dev-checkout](global-hook-runs-dev-checkout.md) | A hook on every call executes whatever branch is checked out. | anti-pattern | Observed |
| [keyword-list-as-security-control](keyword-list-as-security-control.md) | A keyword list decides what counts as security work, and misses fail silently. | anti-pattern | Observed |
| [reviewer-limit-reported-as-clean](reviewer-limit-reported-as-clean.md) | A reviewer that stopped at its limit is logged like a clean pass. | anti-pattern | Observed |
| [adjacent-shape-defeats-new-control](adjacent-shape-defeats-new-control.md) | A new control works on the tested input and fails on its neighbour. | anti-pattern | Reproduced (remedy); Observed |
| [shape-filters-on-model-controlled-text](shape-filters-on-model-controlled-text.md) | A grounding check exempts a text shape the model can produce at will. | anti-pattern | Observed |
| [silent-no-op-safety-configuration](silent-no-op-safety-configuration.md) | A safety rule is documented but not enforced, or set to a value that never fires. | anti-pattern | Reproduced (remedy); Observed |
| [stub-only-setup-tests](stub-only-setup-tests.md) | Config generators tested only against a stub of the real tool. | anti-pattern | Observed |
| [vacuous-regression-test](vacuous-regression-test.md) | A regression test passes without the fix. | anti-pattern | Reproduced; Observed |
| [narrow-json-error-catch](narrow-json-error-catch.md) | Catching only `JSONDecodeError` crashes on other malformed input. | anti-pattern | Observed |
| [main-vs-head-differential](main-vs-head-differential.md) | Was a reported gap caused by this change, or already there? | pattern | Observed |
| [prior-default-floor-regression-test](prior-default-floor-regression-test.md) | A "can only raise" heuristic ships with a lowered default. | pattern | Observed |
| [eval-scorer-review](eval-scorer-review.md) | A loose eval scorer makes every reported number wrong. | pattern | Observed |
| [tool-call-health-check](tool-call-health-check.md) | A model server is healthy on completions and broken for tool calls. | pattern | Observed |
| [property-tests-after-payload-ceiling](property-tests-after-payload-ceiling.md) | Hand-written adversarial inputs stop finding bugs. | pattern | Observed |
| [idempotency-keys-for-side-effects](idempotency-keys-for-side-effects.md) | A retried agent action runs its side effect twice. | pattern | Observed (design gap) |

Evidence tiers are explained in the [README](../README.md#evidence). "Reproduced (remedy)" means a test in this repository exercises the fix, not the original failure.

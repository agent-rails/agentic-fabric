# Engineering Pitfalls

Cross-cutting gotchas that cost real debugging time once, promoted so no
agent re-derives them. Each entry: what happened, why it's non-obvious,
how to avoid it.

## 1. PyPI name-collision "ultranormalization"

PyPI's registration-time similarity check treats hyphens, underscores, and
case as equivalent when comparing a new package name against existing
ones. A name with zero literal overlap can still be rejected as "too
similar to an existing project."

- Before registering a new PyPI distribution name, check it doesn't
  collapse to an existing name under: lowercase + strip `-`/`_`.
- Example: `agentguard` collided with both `agent-guard` and
  `agentguard-security` (unrelated projects) purely on normalized form.
- Import paths, CLI command names, and the GitHub repo name are all
  independent of the PyPI distribution name — renaming the PyPI name to
  dodge a collision breaks nothing else.

## 2. Vacuous test via argument-evaluation order

Python evaluates function arguments left to right, before the call body
runs. A test can pass for the wrong reason if an earlier argument raises
before the code path under test is ever reached.

- Example: `f(_b64u_decode(bad_field), canonicalize(nested_payload))` —
  if `bad_field` is invalid, `_b64u_decode` raises first; the
  `canonicalize` call (and whatever it was supposed to exercise) never
  runs. The test still shows green.
- Symptom to watch for: a regression test that passes both before AND
  after a fix is applied — no diff in behavior when the fix is reverted.
- Mitigation: mutation-test the test itself (temporarily revert the fix,
  confirm the test goes red) before trusting it as a real regression
  guard, especially for security-critical "never raises" contracts.

## 3. Hand-picked-payload review hits a ceiling — switch to property-based testing

Manual adversarial review (hand-crafting malicious payloads) finds real
bugs but each pass tends to find exactly one new bug via one new root
cause, then plateaus — not because the code is clean, but because the
next bug needs a payload shape the reviewer didn't think to hand-write.

- Signal to switch: 3+ manual review passes, each finding one distinct
  bug, no two bugs sharing a root cause.
- Fix: state the invariant once ("this function never raises on
  attacker-controlled input") and let a generator (e.g. Hypothesis)
  search the input space, rather than continuing to hand-pick payloads.
- Caveat: the property test itself needs the same scrutiny as pitfall
  #2 — a generator driving a resolver/mock that always short-circuits
  (e.g. always raises regardless of input) never exercises the real
  vulnerable path either. Verify the property test's negative control
  fails when the fix is reverted.

Source: agent-warrant's `Grant.verify()` hardening (4 manual review
passes, then Hypothesis) and agent-guard's PyPI rename, both 2026-08.

## 4. Side-effecting tools need idempotency keys, not just approval gates

A money-moving or state-changing tool (place a supply order, issue a
refund, book a slot) can be re-dispatched by a retry, a resumed session,
or an operator re-running a command — an approval threshold gates whether
an action is *allowed*, it does not stop the *same* allowed action from
executing twice.

- Symptom: a retried or resumed call to an already-executed side-effecting
  tool re-runs the effect (double order, double refund) instead of
  returning the original result.
- Fix: key side effects on something stable across a retry (a client
  idempotency token, or `(task_id, step, args)`), store the outcome, and
  make a repeat of the same key a no-op that returns the prior result.
- Found via gap analysis against `sme-agent-template`'s `place_supply_order`
  / `issue_refund` (neither has one) while reviewing an external
  agent-backend architecture reference — not yet fixed as of this entry.

Reference: "Designing the Backend for Agent Systems" (Karan, 2026-08) —
job state machines, wall-clock timeouts distinct from turn-count limits,
and prompt-cache layout discipline (static content before dynamic, one
misplaced variable silently zeroes the hit rate) are the other real,
reusable points from that piece. Worth a re-read before building anything
that looks like a job queue or a hosted multi-tenant agent API — most of
its infra layers (queue/worker autoscaling, per-tenant rate limiting) are
sized for that shape of system, not this stack's local-first tools.

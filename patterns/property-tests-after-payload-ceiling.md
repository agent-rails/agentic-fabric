# Switch to property-based tests when hand-picked payloads plateau

Kind: pattern.

## Problem

Manual adversarial review, where a reviewer hand-writes malicious inputs, finds real bugs but tends to find one per pass, each with a different root cause. The next bug needs an input shape nobody thought to write.

## Context

Parsers, verifiers, canonicalisers and other code with an invariant over attacker-controlled input, such as "never raises" or "rejects every tampered token".

## The pattern

- Signal to switch: three or more manual passes, each finding one distinct bug, no two sharing a root cause.
- State the invariant once and let a generator search the input space (property-based testing, for example Hypothesis in Python).
- Give the property test the same scrutiny as any regression test: it needs a negative control that fails when the fix is reverted. A generator that drives a mock which always short-circuits never reaches the vulnerable path.
- Keep the hand-written payloads as fixed regression cases alongside the property.

## Evidence

Observed: hardening of one token-verification function, 2026-08. Four manual review passes each found one distinct bug before the work moved to property-based tests. n = 1; how many further bugs the property tests found is not recorded in the logs used here.

## When it does not hold

A small, finite input domain can be enumerated exhaustively, which beats sampling it.

## Related

- [vacuous-regression-test](vacuous-regression-test.md)
- [adjacent-shape-defeats-new-control](adjacent-shape-defeats-new-control.md)

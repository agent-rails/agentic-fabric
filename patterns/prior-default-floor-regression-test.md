# Test a "can only raise" heuristic against the old default's floor

Kind: pattern.

## Problem

A change adds a heuristic that is said to only raise a tier (a risk classifier, a keyword escalator) and, in the same diff, lowers the base default. Every input the heuristic misses now lands below where it used to.

## Context

- A diff that adds an escalation heuristic and changes a base default, tier or threshold.
- A diff that prunes a keyword list or allowlist feeding an escalation path.

## The pattern

1. Diff the base default, old against new. If it went down, the heuristic is now the floor.
2. List security-relevant inputs the heuristic does not match (identity and access terms, auth refactors, names of security-critical components).
3. Assert each still reaches the old tier.
4. Run the test on the pre-fix commit and confirm it fails.
5. Treat pruning a keyword that feeds escalation as a change to the floor, and test it the same way.

If the test cannot pass without the heuristic catching everything, restore the default; do not grow the list.

## Evidence

Observed: one subagent routing change, 2026-11-14, from the review log. Lowering one agent's default sent security work the classifier missed (an authentication refactor, then identity and access terms) below the old floor; found across two review cycles and fixed by restoring the default, with a test that failed first. Lowering that default was then rejected as a decision, because it relied on detection to lift security work back up. n = 1.

## When it does not hold

If the base default stays the same or goes up, the old floor still holds and a hit-rate test is enough.

## Related

- [keyword-list-as-security-control](keyword-list-as-security-control.md)
- [main-vs-head-differential](main-vs-head-differential.md)
- [adjacent-shape-defeats-new-control](adjacent-shape-defeats-new-control.md)

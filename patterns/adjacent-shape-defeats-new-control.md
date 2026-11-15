# An adjacent input shape defeats a new control

Kind: anti-pattern.

## Problem

A new guard, gate, filter or limit is built and tested against one shape of input. A neighbouring shape the author did not list defeats it, because the implementation, not just the tests, assumed the tested shape was the only one.

## Context

Any change that adds or tightens a control. Reviewers who re-read the diff instead of re-deriving the input space sign it off.

## What goes wrong

Typical pairs where one side is handled and the other is not:
- empty vs quoted-empty (`KEY=` vs `KEY=""`)
- a flag as an argument vs the same text inside a quoted value or after a shell operator
- an item that consumes stock vs one with no stock lines, so a per-item cap never fires
- loopback vs advertised host, when one string feeds both a bind address and a base URL
- a "can only raise" heuristic shipped together with a lowered default

A mitigation accepted on a documentation claim, not a probe, is the same failure one level up.

## Do instead

For every control a diff adds or changes:
1. Observe it fire: build the input that should trip it and show the deny, exit code or log line. Not observed means not reviewed.
2. Try the adjacent shape: the sibling path, the quoted-empty value, the same call one layer up.
3. Break its dependency on purpose (missing binary, unset variable, failed probe) and check it denies.
4. Tie every claim in the change description to the line that makes it true.

## Evidence

- Reproduced (the remedy): [`plugins/fabric-gates/tests/gh-pr-merge-gate.test.sh`](../plugins/fabric-gates/tests/gh-pr-merge-gate.test.sh) checks `--repo` after a shell operator, inside a quoted value, repeated and quoted; [`plugins/fabric-gates/tests/gates.test.sh`](../plugins/fabric-gates/tests/gates.test.sh) checks a sibling of a protected directory, a protected path that does not exist yet, a branch delete vs a branch create, and `switch -c` inside a command chain.
- Observed: 6 recorded instances across 3 codebases, 2026-09-12 to 2026-11-14, counted from one review knowledge base. In one, a mitigation accepted on a documentation claim was disproved in the next cycle by an executed probe on the shape it had not covered.

## When it does not hold

Inputs already constrained by a schema or type system to a closed set; enumerate the set and test all of it.

## Related

- [prior-default-floor-regression-test](prior-default-floor-regression-test.md)
- [shape-filters-on-model-controlled-text](shape-filters-on-model-controlled-text.md)
- [silent-no-op-safety-configuration](silent-no-op-safety-configuration.md)

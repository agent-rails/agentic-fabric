# A hook called fail-closed that has no failure handling

Kind: anti-pattern.

## Problem

A PreToolUse hook is documented as enforcing a rule, but only its handled paths deny. A crash, a timeout or an unexpected exit code lets the tool call run, and nothing says the control was skipped.

## Context

Any Claude Code command hook whose job is to stop something: merge gates, write guards, routing enforcement. `onFailure` needs Claude Code 2.1.295 or later.

## What goes wrong

- An uncaught exception exits 1. Exit codes other than 0 and 2 are non-blocking unless the hook entry sets `"onFailure": "block"`, so the call runs.
- A slow dependency pushes the hook past its timeout. Same result.
- Even with `"onFailure": "block"`, a hook that prints output that is not a decision and exits 0 does not block.

The control looks enforced and is not, exactly when something unusual is happening.

## Do instead

- Set `"onFailure": "block"` on every security hook entry.
- Catch every error inside the hook and turn it into a deny that names the cause and the fix. Never exit 0 with partial or malformed output.
- Validate stdin types before use; decide on empty stdin too.
- Break it on purpose: malformed stdin, a raised error, a forced timeout. All three must block.

## Evidence

- Reproduced: [`docs/evidence/onfailure-check.sh`](../docs/evidence/onfailure-check.sh) (four short model calls, Claude Code 2.1.301). Exit 1 blocks only with `onFailure: "block"`; a timeout blocks with it; malformed output with exit 0 runs even with it. Results table in [decision 0002](../docs/decisions/0002-fail-closed-hooks.md).
- Observed: one enforcing hook, 2026-11, shipped for review with uncaught-exception paths and no `onFailure`; found and fixed in review before merge. n = 1, from the review log.

## When it does not hold

Advisory hooks (naming conventions, nudges) may fail open on purpose. Say so in their docs; the branch-prefix hook in `fabric-gates` does.

## Related

- [silent-no-op-safety-configuration](silent-no-op-safety-configuration.md)
- [adjacent-shape-defeats-new-control](adjacent-shape-defeats-new-control.md)
- [decision 0002](../docs/decisions/0002-fail-closed-hooks.md)

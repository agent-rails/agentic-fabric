# Safety configuration that silently does nothing

Kind: anti-pattern.

## Problem

A safety rule or value is either documented but never enforced, or enforced but shipped with a placeholder that can never trigger. Both run normally and log nothing unusual.

## Context

Limits, thresholds, derived file names, required settings: anything the docs say protects you and the code may or may not implement.

## What goes wrong

- Documented, not enforced: "the ledger file name is derived from the config name" with no code doing it. Rename the config and an empty ledger starts at exit 0.
- Enforced, wrong placeholder: an approval limit set far above any realistic amount. The code is correct; the gate never fires.

The operator cannot tell "working" from "disabled" from the logs.

## Do instead

- For every "X is derived from Y" or "X is capped at Y" line in the docs, find the code that makes it true. No code, no claim; enforcing it is usually a few lines.
- Pick the placeholder's failure direction. Too low fails loud on first use; too high fails silent forever. Prefer a required setting with no default, or a value that refuses to start.
- Treat unreadable or invalid settings as errors that name the fix, not as a reason to fall back to permissive defaults.

## Evidence

- Reproduced (the remedy): [`plugins/fabric-gates/tests/gates.test.sh`](../plugins/fabric-gates/tests/gates.test.sh). With no `branch_prefix` set, branch creation is denied and the deny names the fix; a config file that is not valid JSON denies; an absolute `protected_paths` entry makes the protected-path check fail closed.
- Observed: one review, 2026-09, found both shapes in a single change. n = 1.

## When it does not hold

- A fallback is fine when it falls to the restrictive value: an invalid `gate_unlock_minutes` falls back to 15 minutes, tested in the same suite.
- Pure tuning values (cache sizes, batch sizes) are not safety controls.

## Related

- [hook-fail-closed-without-onfailure](hook-fail-closed-without-onfailure.md)
- [reviewer-limit-reported-as-clean](reviewer-limit-reported-as-clean.md)
- [decision 0003](../docs/decisions/0003-settings-not-edits.md)

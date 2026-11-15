# 0002: Security hooks fail closed, and their errors are decisions

Status: accepted.

## Decision

Every security hook sets `"onFailure": "block"` and catches its own errors, turning each into a deny that names the cause and the fix. The branch-prefix hook is the exception: it enforces a naming convention, so its errors let the call through.

## Evidence

Observed on Claude Code 2.1.301 with a plugin hook and a 2-second timeout. Reproduce with [onfailure-check.sh](../evidence/onfailure-check.sh) (four short model calls):

| Hook behaviour | With `onFailure: "block"` | Without it |
|---|---|---|
| exits 1 | call blocked | call ran |
| sleeps past the timeout | call blocked | not tested |
| prints malformed output, exits 0 | call ran | not tested |

The last row is why catching errors inside the hook is required as well: output that is not a decision, with exit 0, is not treated as a failure.

## Rejected

- Fail open everywhere. A hook that breaks silently becomes a hook that is not there.
- `onFailure: "block"` alone. It does not cover malformed output with exit 0.

## Would change if

Claude Code treated malformed hook output as a failure.

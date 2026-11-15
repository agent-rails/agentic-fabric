# A regression test that passes without the fix

Kind: anti-pattern.

## Problem

A new regression test goes green for a reason unrelated to the bug, so it would also pass on the code before the fix.

## Context

Tests for "never raises", "always denies" and other negative contracts, where an early error looks the same as the right error.

## What goes wrong

- Argument order: Python evaluates arguments left to right before the call. In `f(decode(bad_field), canonicalize(payload))`, `decode` raises first, `canonicalize` never runs, and a test expecting an error passes.
- A mock or generator that always short-circuits (always raises, always returns the same value) never reaches the code under test.
- A runner that finds no tests reports success.

Symptom: the test passes both before and after the fix.

## Do instead

- Run each new regression test on the pre-fix commit and confirm it fails.
- Mutation-check the test: revert the fix or break the implementation on purpose; at least one test must go red.
- For property-based tests, include a negative control that fails when the fix is reverted.
- Make "nothing ran" a failure in CI.

## Evidence

- Reproduced: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml), step "Run every plugin test suite", exits 1 when it finds no suite to run.
- Observed: the argument-order case once, in hardening of a token-verification function (maintainer's pitfalls log, 2026-08 entries; n = 1). Mutation checks on this project's release tooling, 2026-11-15: removing input normalisation, the symlink check, the credential-before-exemption ordering or the identity check each failed at least one of 46 tests. Those tests are not yet published.

## When it does not hold

Characterisation tests that pin existing behaviour are expected to pass before and after a refactor; they are not regression tests for a fix.

## Related

- [property-tests-after-payload-ceiling](property-tests-after-payload-ceiling.md)
- [stub-only-setup-tests](stub-only-setup-tests.md)

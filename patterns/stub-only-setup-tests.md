# Setup scripts tested only against a stub

Kind: anti-pattern.

## Problem

A script that generates or patches another tool's configuration is tested only against a stubbed version of that tool. The real tool's schema validation never runs until someone installs it.

## Context

Installers, plugin manifests, config generators, anything whose output another program parses and validates.

## What goes wrong

A stub encodes the author's belief about the schema. When the belief is wrong, every test passes and the error surfaces at install time, on someone else's machine.

## Do instead

- Keep stubs for fast unit coverage.
- Add at least one run against the real tool in a throwaway profile, through the tool's own validator or headless mode.
- Put the real validator in CI when the tool can run there; until then, run it before every release and say that it is manual.

## Evidence

Observed:
- One setup script, 2026-11: stub-based tests passed; the real tool's validate command in a throwaway profile rejected the generated manifest. n = 1, from the review log.
- Building these plugins, 2026-11-15, Claude Code 2.1.301: `claude plugin validate --strict` rejected a manifest location the planned file layout assumed, and a clean-profile run with `claude -p --plugin-dir` was what confirmed the gates deny as documented.

CI here does not yet run `claude plugin validate`; it is run locally before each release (see [CONTRIBUTING](../CONTRIBUTING.md)).

## When it does not hold

If the tool has no validator and no headless mode, pin its published schema and validate against that, and record that the real tool was not run.

## Related

- [vacuous-regression-test](vacuous-regression-test.md)
- [tool-call-health-check](tool-call-health-check.md)

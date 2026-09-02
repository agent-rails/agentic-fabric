---
name: judge-review-convergence
description: Run the review-convergence judge in shadow mode for cycle 2 or 3 of a PR review. Use after reviewer findings and deterministic checks are available.
argument-hint: "<evidence-bundle-json-path>"
---

Run a non-authoritative review-convergence evaluation.

## Preconditions

- The input is a local JSON file conforming to
  `~/.claude/evals/review-convergence/evidence.schema.json`, containing an
  immutable PR head SHA, cycle number, stable finding IDs/status/evidence,
  deterministic check results, reviewer vendor and priming metadata, and the
  existing heuristic result.
- Only cycle 2 or 3 is eligible. Otherwise report `not_run`.
- Screen the bundle for credentials, customer data, private keys, and
  non-approved private source before any cross-vendor call. On risk, report
  `human_review` without sending it externally.

## Execution

1. Read `~/.claude/evals/review-convergence/rubric.md` and schema.
2. Invoke `your-review-convergence-judge` with:

   ```text
   REVIEW_CONVERGENCE_MODE: shadow
   SECURITY_RELEVANT: <true|false>
   EVIDENCE_BUNDLE:
     <bundle JSON>
   ```

3. Validate its response through
   `~/.claude/scripts/validate-judge-verdict.sh`.
4. Append one JSONL record to
   `~/your-pr-reviewer/wiki/evals/review-convergence.jsonl` containing only the
   normalized verdict, rubric version, judge vendor/model, repo, PR, head SHA,
   timestamp, and `authoritative: false`. Do not persist raw model output or
   evidence content, and do not overwrite prior records.
   Create the `evals/` directory if it does not exist.
5. Return `judge_shadow: <continue|converged|human_review>` to the orchestrator.

## Hard boundaries

- This skill cannot alter a PR verdict or stop a cycle while ADR-0007 is
  Proposed.
- It cannot approve, send, push, merge, or mark a PR ready.
- Failure, invalid output, missing evidence, or missing cross-vendor coverage
  becomes `human_review`, never `converged`.

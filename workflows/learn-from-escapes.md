# Learn from escapes

## Goal

Every defect that gets past review makes the review measurably better at that class of defect, and no change to a reviewer ships without showing it did not get worse.

## Steps

1. An escape is a defect found after merge (post-merge review, CI on `main`, production, a user report) in code that passed review.
2. Check the parent commit first ([main-vs-head differential](../patterns/main-vs-head-differential.md)). Record whether the reviewed change introduced the defect or it was already there.
3. Write an escape record (template below) in your review log.
4. Turn it into a seeded-defect eval case: the smallest diff with the defect planted, a grader that it is detected and one that it is located. If the fix could teach the reviewer a false positive, add a trap case too.
5. Run the suite on every change to an agent definition or review prompt, before merge. Record the score with the grader version.
6. Once a month, group escapes by the stage that missed them and why.

```yaml
escape:
  found: 2026-01-31            # UTC date
  found_by: post-merge-review  # post-merge-review | ci-main | production | user-report
  change: <link to the change that passed review>
  introduced_by_change: true   # false if the parent commit has the same defect
  defect_class: path-traversal
  missed_by: cross-vendor-reviewer
  why_missed: out-of-scope     # not-run | stalled-at-limit | out-of-scope | ran-and-missed | primed
  severity: HIGH
  eval_case: evals/<case-name>/  # added seeded case; empty until written
  score_before: 0.91
  score_after: 0.95
  grader_version: 3
```

## What enforces it

Not yet enforced; manual. The template and suite are planned for the `fabric-review` plugin.

## Evidence

Observed:
- Review log, 2026-09-12 to 2026-11-14, 23 cycles over 12 subjects: 7 of the 12 cycles after cycle 1 still reported a BLOCKER or HIGH, so severe findings keep arriving late. One post-merge review reported a blocking gap; the parent-commit check showed it predated the change.
- A seeded-defect review suite (unreleased): 11 cases (7 seeded, 2 clean, 2 trap). Latest run, 2026-10-30, Claude Code 2.1.301: 9 of 11 cases passed, overall score 0.95, about US$2.80. Six recorded runs over two days scored 0.20 to 0.95 while the suite was being built.
- Not yet observed: the loop itself. The suite's cases are classic defect classes; none was derived from a recorded escape.

## Failure modes

- No post-merge review means no escapes are found and the log looks clean.
- Seeded cases that name the defect in a comment or file name test reading, not reviewing.
- Loose graders inflate the score; see [eval-scorer-review](../patterns/eval-scorer-review.md).
- Cost per run discourages running it. Keep the suite small and run it only on reviewer changes.
- Tuning prompts to the suite. Hold back some cases, and watch the escape rate rather than the score.

## Adopting it

1. Add the record template to your review log and fill it for the next escape.
2. Start a suite with three seeded cases, one clean and one trap; run it on the next reviewer change.
3. Never compare scores across grader versions.

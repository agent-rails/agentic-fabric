# Evaluation

**Status: there are no measured results for the review cascade, the severity calibration or the prompt-versus-hook claim.** The hook gates have tests (see `scripts/*.test.sh`); everything else this repo says about how well it works is a design intent or the author's experience over months of daily use, not a measurement. This page says what would be measured, how, and what would count against the design. It is a plan, and it will be replaced by results when there are results.

## Claims in this repo that have no measurement

| Claim | Where | What is missing |
|---|---|---|
| A model ignores a prompt instruction "about 1 in 5" times | DESIGN-PRINCIPLES, principle 2 | No source and no experiment. Treat the number as illustrative until measured |
| Cross-vendor review catches defects a single reviewer misses | README, ADR-0005 | The ADR argues that same-family reviewers share blind spots. No comparison on a labelled set |
| Unverified blocker claims are downgraded, so severity is calibrated | README design principles | No measurement of how often a downgraded claim was real |
| A same-vendor fresh pass still catches real issues | ADR-0008 | The ADR cites two real bugs found in the bundle's own history. That is two anecdotes, with no comparison against the primed single pass |
| Dogfooded daily for months | README | A statement of use, not an outcome |

## Questions

1. **Do the hook gates hold?** Metric: bypass rate over a catalogue of command forms, reported per hook and per route. Status: started. The PR create and merge gates have table-driven tests that include known bypasses and fail on the earlier implementation. The branch, write-scan and gate-page hooks have no equivalent catalogue.
2. **Does the cascade find more real defects than one reviewer?** Metric: recall of seeded defects at a fixed false-positive budget, with token cost reported next to it. Arms: (a) one reviewer; (b) one reviewer plus the same-vendor fresh pass; (c) the cross-vendor cascade.
3. **Is severity calibrated?** Metric: for each severity label the reviewer assigns, the share of findings that are real defects. A calibrated reviewer's blockers should be real more often than its minors.
4. **How often is a prompt-only rule skipped, compared with the same rule as a hook?** Metric: skip rate over repeated runs of the same task, per rule, with the intervals shown. This is what would replace the illustrative figure above.

## Design for questions 2 and 3

- **Corpus.** Real diffs with defects injected by hand, each with a written ground truth: the file, the line range, the defect class and the severity a careful reviewer would assign. Classes to cover: injection, missing authorization, race conditions, secret handling, infrastructure misconfiguration, a plausible-but-wrong change. Include clean diffs, so false positives are countable.
- **Held-out set.** Prompts are tuned on one part of the corpus and scored on a part that was not used for tuning.
- **Repeats.** At least three runs per diff per arm, because the output varies between runs. Report the spread, not a single run.
- **Fixed inputs.** Model identifiers, prompt versions and the harness commit are recorded with each run.
- **Scoring.** A finding counts as a hit only if it names the seeded location and class. A written rubric is applied before any arm's output is read.
- **Cost.** Tokens and wall time per arm, so a better arm that costs ten times as much is visible.

## Threats to validity

- The author writes the seeded defects, so they reflect the author's idea of a bug. Mitigation: take defect classes from public advisories and have a second person write part of the set.
- Public repositories may be in the models' training data. Mitigation: use freshly written changes for the held-out set.
- The same model family reviews and, in arms (a) and (b), is also the one that wrote some of the code under review. A same-family blind spot is exactly what arm (c) claims to fix, so arm (c) must use a different family and the report must say which.
- Small N. State the number of diffs and the intervals; do not report a percentage without them.
- Model versions change. Results are dated and versioned, and are not a standing property of the design.

## Order of work

1. Extend the red-team catalogue to the remaining hooks (question 1).
2. A pilot of about ten seeded diffs on one arm, to measure cost and to check that the scoring rubric is usable. The cost of the full run is not estimated until then.
3. The full comparison for questions 2 and 3, then question 4.
4. Publish the numbers, the corpus and the harness together, including results that do not favour the design.

If the cascade does not beat a single reviewer at equal cost, this page and the README will say that.

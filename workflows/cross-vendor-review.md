# Cross-vendor review

## Goal

Cut the blind spots a reviewer shares with the author. A reviewer from the same model family as the agent that wrote the change tends to accept what it would have written itself.

## Steps

1. Decide whether the cross-vendor reviewer runs. Default: yes. Skip only when all three hold: the diff is docs-only, under 100 changed lines, and touches no risk path (CI workflows, container files, infrastructure code, deploy manifests, auth, hooks, secrets, agent definitions and prompts, threat-model docs). A re-review of fix commits never skips, whatever its size.
2. The cross-vendor reviewer reviews the recorded head, lists what it ran and what it skipped with a reason, and tags each finding with its evidence. Severity is capped by evidence: execution output may be BLOCKER; a source quote or an external doc at most HIGH; an unverified hypothesis at most MEDIUM.
3. If it does not run (quota, turn limit, permission denial), stop with no verdict and say so in the review header. The operator chooses: retry, or a same-vendor fallback reviewer whose findings are labelled `cross_vendor: false` in the header and the log. Never substitute silently.
4. The PR reviewer synthesises: checks the head SHA and changed files, reproduces findings, sets severity.
5. Cycle bounds:
   - At most 3 review cycles. After cycle 3, non-BLOCKER findings become tracked follow-ups.
   - Only BLOCKER and HIGH block a merge.
   - From cycle 2, a new finding from a single reviewer drops one severity tier unless another reviewer or a reproduction confirms it.
   - A cycle has converged when its BLOCKER and HIGH count is under half the previous cycle's, confirmed by one unprimed pass (no prior findings in the prompt). Reviewers given earlier findings anchor on them.

## What enforces it

Not yet enforced; manual. A `fabric-review` plugin is planned, with cross-vendor review off by default so no code leaves the machine unless you opt in.

## Evidence

Observed, review logs, 2026-09-12 to 2026-11-14, one maintainer:
- 18 cross-vendor passes over 12 review subjects (pull requests and one plan). 16 produced a review; 2 did not (a provider usage limit with the fallback also stopped at its turn limit; a local permission classifier blocking the outbound call).
- Of the 9 passes where the log compares the two reviewers, 6 recorded a finding only the cross-vendor reviewer made, 2 agreed, and 1 diverged; its main claim was refuted by execution.
- 23 logged cycles over 12 subjects: 3 subjects reached cycle 3 and none went past it. 7 of the 12 cycles after cycle 1 still reported a BLOCKER or HIGH.

## Failure modes

- A stalled pass logged as clean. See [reviewer-limit-reported-as-clean](../patterns/reviewer-limit-reported-as-clean.md).
- A local permission layer denies the second vendor's CLI and the review quietly becomes same-vendor. Surface it in the header.
- Over-cascading on trivial docs creates findings that are declined on re-read; that is what the skip rule is for.
- Data egress: the diff goes to a second provider. Screen for credentials and customer data first, and run the second CLI read-only.

## Adopting it

1. Install a second vendor's CLI with a read-only sandbox mode and decide what code may be sent to it.
2. Give its reviewer the evidence contract in step 2 and a tool-call budget.
3. Log one record per pass with `cross_vendor: true|false`, a status that distinguishes "not obtained" and "pending", and finding counts by severity.

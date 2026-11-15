# Review-first pull requests

## Goal

No agent-authored change reaches `main` without a review, and what merges is the commit that was reviewed.

## Steps

1. The agent works on a branch with your prefix.
2. It opens the pull request as a draft: `gh pr create --draft`.
3. Review runs against the draft at a recorded head SHA. The reviewer's output starts with that SHA and the changed files; check both against `gh pr view --json headRefOid,files` before reading any finding.
4. Fix and re-review, within the bounds in [cross-vendor review](cross-vendor-review.md).
5. A human marks it ready (`gh pr ready`) once the review at that head is accepted.
6. Merge only the reviewed head: `gh pr merge <number> --match-head-commit <reviewed-sha>`. `gh` refuses the merge if the head is different.

## What enforces it

`fabric-gates`, on the agent's Bash tool calls (see its [What runs](../plugins/fabric-gates/README.md#what-runs) table):
- `gh pr create` without `--draft` is denied.
- `gh pr merge` is denied on a draft, when the PR's head on GitHub differs from its branch tip, when the target repository is ambiguous, and whenever PR state cannot be read.
- Branch creation without the configured prefix is denied.
- Edits to the hooks, settings and agent definitions need a human unlock.

Not enforced by the plugin, manual today:
- That the merged head is the reviewed head. Use `--match-head-commit`, and server branch rules: a required pull request with "Dismiss stale pull request approvals when new commits are pushed" if your reviews are GitHub approvals.
- `gh pr ready` is not gated, so an agent can mark its own PR ready.
- Anything outside the agent's Bash tool: the web UI, the API through `curl`, your own terminal.

## Evidence

- Reproduced: [`plugins/fabric-gates/tests/`](../plugins/fabric-gates/tests/) (the shell suites) and [`docs/evidence/onfailure-check.sh`](../docs/evidence/onfailure-check.sh).
- Observed: gate decision log, 2026-10-11 to 2026-11-14, 19 sessions, one maintainer. Rows without a session ID come from test suites and are excluded; probes run inside real sessions cannot be separated out.
  - `gh pr create`: 120 calls, 14 (12%) denied for a missing `--draft`.
  - `gh pr merge`: 68 calls; 47 allowed, 8 denied as drafts, 13 denied because PR state could not be read. No stale-head denial occurred.
  - Protected paths: 6 edits denied, 11 allowed inside a fresh unlock window. Branch prefix: 7 denials.

## Failure modes

- The PR gates accept only the plain form, so a chained command such as `git push && gh pr create --draft` is denied; run each command on its own, and pass a PR body with `--body-file` rather than a heredoc. They deny any executable mention they cannot resolve to that form, including `gh pr merge --help` run outside a repository (observed 2026-11-15). Expect some denials to be noise, and read the reason.
- A review that stalled at a turn limit, logged as clean, makes this whole flow certify nothing. See [reviewer-limit-reported-as-clean](../patterns/reviewer-limit-reported-as-clean.md).
- Moving the branch while a review is in flight wastes the review; the reviewed SHA is no longer the head.

## Adopting it

1. `claude plugin install fabric-gates@agentic-fabric` and set `branch_prefix`.
2. Turn on server branch rules for `main`: pull request required, no force-push, required CI.
3. Put `--match-head-commit` in the merge step your agents and you use.
4. Decide who may run `gh pr ready`, and write it down.

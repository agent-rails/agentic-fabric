---
name: review-pr
description: Review a GitHub PR using the pr-reviewer agent with wiki-backed institutional knowledge. Use when user provides a PR URL or says "review pr", "review this pr", "code review".
argument-hint: "<pr-url or owner/repo#number>"
---

Review the PR using the `pr-reviewer` agent ecosystem.

## Input

The user provides one of:
- Full URL: `https://github.com/your-org/some-repo/pull/42`
- Shorthand: `your-org/some-repo#42`
- Just a number (assumes current repo): `#42`

Parse the PR reference and pass it to pr-reviewer.

## Execution

1. **Evaluate cross-vendor cascade policy + prefetch PR data** (orchestrator-side, before spawning anyone):
   - Fetch in a single parallel Bash batch — combines cascade decision with downstream-agent prefetch so each agent does not re-run the same `gh` calls:
     ```bash
     gh pr view {n} --json title,body,author,files,additions,deletions,changedFiles,baseRefName,headRefName,headRefOid,state,labels
     gh pr diff {n} --repo {owner}/{repo}
     ```
   - Apply the skip rule from `~/pr-reviewer/wiki/conventions/cascade-default-policy.md`: cross-vendor-reviewer cascades unless ALL three hold — diff is docs-only, total LOC < 100, no file touches `.github/workflows|actions/**`, `actions/**`, `**/Dockerfile`, `**/terraform|helm|k8s|argocd|applicationsets/**`, or any always-cascade path.
   - If skip rule applies → spawn pr-reviewer only.
   - If skip rule does NOT apply → spawn pr-reviewer + cross-vendor-reviewer as peers in parallel; once both return, pass cross-vendor-reviewer's `CROSS_VENDOR_REVIEW:` block to pr-reviewer as `CROSS_VENDOR_INPUT:` for synthesis.
   - Surface the cascade decision in the user-facing review header (e.g. "cycle 1 — pr-reviewer only (docs-only diff, skip rule applied)" or "cycle 1 — pr-reviewer + cross-vendor").
   - **Pass the fetched data to each spawned agent as a `PR_PREFETCH:` block** in the prompt. Saves 5–15s per agent on cold start by avoiding redundant `gh` round-trips.

2. Spawn the `pr-reviewer` agent with this prompt:

```
Review this PR: {pr_reference}

PR_PREFETCH:
  pr_view: <gh pr view JSON inline>
  diff: |
    <gh pr diff output inline>

Steps:
1. Use the PR_PREFETCH block above — do not re-fetch unless PR_PREFETCH is absent. Optionally pull comments via `gh api repos/{owner}/{repo}/pulls/{n}/comments` if needed.
2. Read wiki context from ~/pr-reviewer/ for this repo, author, and relevant conventions
3. Analyze the diff — only flag production-impacting issues
4. Output review findings
5. Delegate to pr-review-scribe to update the wiki with findings from this review
```

3. **Verify grounding before presenting** (orchestrator-side anti-hallucination check):
   - PR-reviewer's response MUST start with a `GROUNDING_OK:` block listing `head_sha` and `changed_files`.
   - Cross-check `head_sha` against `gh pr view {n} --json headRefOid`. If they don't match, halt and re-run.
   - Cross-check `changed_files` against `gh pr view {n} --json files`. If pr-reviewer's list is empty, fabricated, or includes paths not returned by `gh pr view`, halt and re-run.
   - For each finding's `File:` citation, confirm the path is in the verified `changed_files` list. Drop any finding that cites a path outside the list (or escalate back to pr-reviewer for a re-run if more than one slips through — that signals a grounding failure, not a single noisy finding).
   - If pr-reviewer returned `GROUNDING_FAILED:` or no checkpoint at all, do NOT present findings to the user. Re-spawn pr-reviewer with explicit grounding facts pasted into the prompt (head SHA + file list from `gh pr view`).
   - Reason: prior runs hallucinated findings against fictional files. This check is cheap and catches it deterministically before the user sees noise.

4. Present the synthesized review to the user, **led by a Merge Decision Pack** — the one-screen verdict + decision drivers at the top, full findings below. See `~/pr-reviewer/wiki/conventions/merge-decision-pack.md` for the format.

5. Ask: **Post as GitHub review?** If yes, use `gh pr review` to submit.

## Post-Review Actions

After presenting the review, offer:
- `[Post]` — Submit as GitHub PR review via `gh pr review {number} --repo {owner}/{repo}`
- `[Comment]` — Post individual inline comments via `gh api`
- `[Draft fixes]` — Invoke `/draft-pr-fixes {pr}` to spawn `patch-drafter` (codex-backed cross-vendor patch drafter). Produces unified-diff patches per finding for cherry-pick. Never auto-applies.
- `[Skip]` — Don't post, wiki still gets updated

Drafting fixes is HITL by design — patches surface for the user's pick, then Claude applies the chosen ones under the standard permission model. Use after the user has read the findings and wants candidate fixes without writing them by hand.

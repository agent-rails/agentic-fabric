---
name: draft-pr-fixes
description: Draft cross-vendor patches addressing findings from a prior PR review. Spawns the scotty agent (codex-backed, read-only sandbox) to produce one unified-diff per finding. Returns the patches for human cherry-pick — never auto-applies. Use after sentinel/spock review when the user wants candidate patches drafted. Trigger phrases include "draft fixes", "draft patches", "scotty fix", "draft the fixes for this PR".
argument-hint: "<pr-url or owner/repo#number>"
---

Draft candidate patches for a PR using the `scotty` agent (codex-backed cross-vendor patch drafter).

## Contract

- **Input**: PR reference + structured findings from a prior review (sentinel + spock output)
- **Output**: one unified-diff patch per addressed finding, plus `unaddressed` list for findings the agent declined to patch
- **Autonomy**: DRAFT-ONLY. Patches are surfaced to the user for cherry-pick. Never auto-applied.

## Input parsing

The user provides one of:
- Full URL: `https://github.com/your-org/some-repo/pull/42`
- Shorthand: `your-org/some-repo#42`
- Just a number: `#42` (assumes current repo)

If invoked immediately after `/review-pr` in the same session, use the findings from that review. Otherwise, ask the user to paste the findings or rerun `/review-pr` first — scotty needs structured findings as input, not just a PR.

## Execution

1. **Confirm findings exist in context.** If not, prompt the user: "Need structured findings to draft against. Paste the review output or run `/review-pr <pr>` first."

2. **Prefetch PR diff** (orchestrator-side, before spawning scotty):
   - If the previous `/review-pr` invocation in this session already prefetched and the data is still in context, reuse it.
   - Otherwise fetch:
     ```bash
     gh pr view {n} --json title,headRefOid,baseRefName,headRefName
     gh pr diff {n} --repo {owner}/{repo}
     ```
   - Pass both to scotty as a `PR_PREFETCH:` block in the prompt. Saves 5–15s on scotty cold start by avoiding the redundant `gh pr diff` call inside the agent.

3. **Spawn scotty** with this prompt:

```
draft_fixes mode. PR: {pr_reference}

PR_PREFETCH:
  pr_view: <gh pr view JSON inline>
  diff: |
    <gh pr diff output inline>

Findings to address:
{paste structured findings here — keep severity, file:line, issue, fix direction}

Steps:
1. Validate data egress screen against the PR diff and findings
2. Use the PR_PREFETCH diff above — do not re-fetch unless PR_PREFETCH is absent
3. Construct UNPRIMED prompt for codex (no sentinel/spock attribution)
4. Invoke codex exec --sandbox read-only with the patch-drafting prompt
5. Validate each patch with git apply --check against the base
6. Return structured SCOTTY_DRAFT output

Return one patch per finding plus the unaddressed list.
```

3. **Present the drafts to the user.** For each patch:
   - Severity + file:line
   - One-line rationale
   - Risk notes (if any)
   - The unified diff (rendered in a fenced ```diff block)

   For each unaddressed finding:
   - Severity + file:line
   - Why scotty declined to patch (out of scope / ambiguous / requires architectural decision)

4. **Offer cherry-pick options:**
   - `[Apply all]` — apply every patch in order
   - `[Apply BLOCKING/HIGH only]` — apply by severity threshold
   - `[Cherry-pick]` — user picks numbered patches
   - `[Skip]` — present-only, no apply

5. **Apply chosen patches** (Claude does this — scotty never writes files):
   - For each chosen patch: `git apply <patch-file>` in the local clone
   - Run `git diff --stat` after each apply to confirm
   - If any patch fails `git apply`, surface the failure and ask the user how to proceed
   - Stage and commit each applied patch as a separate commit, with the rationale as the body and a `fix(...)` conventional-commit subject derived from the finding
   - DO NOT push automatically — leave the commits local for the user to push

6. **Report back:**
   - Which patches applied, which failed, which were skipped
   - The local commit SHAs created
   - A reminder to push when ready: `git push origin <branch>`

## Guardrails

- **NEVER push without explicit user confirmation.** Local commits only.
- **NEVER apply a patch that failed `git apply --check`.** Surface the failure.
- **NEVER apply a patch to a file outside the original PR's diff scope.** Sandbox-escape signal — surface and refuse.
- **NEVER use `--no-verify`** when committing — let pre-commit hooks run.
- **Cherry-pick is the default mental model.** Even on `[Apply all]`, walk patch-by-patch so a mid-stream failure doesn't half-apply a fix.

## Composition with /review-pr

Typical flow:
1. `/review-pr <url>` → sentinel (+ optionally spock) returns findings
2. User decides whether to post the review and/or draft fixes
3. `/draft-pr-fixes <url>` → scotty drafts patches based on the in-session findings
4. User cherry-picks
5. Claude applies + commits locally
6. User reviews and pushes

The `/review-pr` skill should offer `[Draft fixes]` as a post-review option that invokes this skill.

---
last_verified: 2026-06-03
sources: [pr:your-org/workflow-templates#72]
---

# GitHub App Token Permission Scope-Cap

## Convention

Any workflow step that mints a GitHub App installation token via `actions/create-github-app-token` MUST include `permission-*` parameters to scope-cap the token to only the permissions required by that step.

## Why It Matters

`actions/create-github-app-token` by default mints a token that inherits ALL installation permissions granted to the GitHub App. If the App was granted `contents:write`, `pull-requests:write`, `issues:write`, and `actions:read` at install time, the minted token carries all of those grants — even if the workflow step only needs `contents:write` for a single commit.

A leaked token (logged, exposed via step output, or extracted via workflow injection) has the full installation blast radius, not the minimal scope the step actually needed.

## Fix

Always add `permission-*` parameters matching only what the step needs:

```yaml
- uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
    permission-contents: write      # scope-cap: only grant what this step uses
```

Do NOT omit the `permission-*` parameters and rely on the header comment claiming "contents:write-only" — the comment describes intent, not enforcement. Only the `permission-*` parameter actually caps the token.

## Detection Heuristic

Grep for `actions/create-github-app-token` steps that lack a `permission-` key:

```bash
grep -B5 -A10 'create-github-app-token' .github/workflows/*.yml \
  | grep -L 'permission-'
```

Any match is a token with uncapped installation scope.

## Real Examples

| Date | PR | Repo | How It Manifested |
|------|-----|------|-------------------|
| 2026-06-03 | [#72](https://github.com/your-org/workflow-templates/pull/72) | workflow-templates | `image-tag-sync.yml` minted an App installation token for protected-branch commits. PR header claimed `contents:write` scope but the original step omitted `permission-contents: write`. Token inherited all installation grants. FIXED in-cycle: `permission-contents: write` added to scope-cap the minted token. Surfaced by cross-vendor reviewer (spock); sentinel did not independently flag. |

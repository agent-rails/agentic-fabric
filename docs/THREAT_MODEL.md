# Threat model

Scope: `fabric-gates` 0.1.0.

## What is protected

- The review gate: an agent merges a pull request only after it has left draft, and only while GitHub's view of its head matches the branch tip. The gate does not record which commit was reviewed; pass `--match-head-commit <sha>` to `gh pr merge` to pin that.
- The enforcement layer: the hooks, settings, agent definitions and rules that make the gates hold, and this project's own settings file.

## Adversary

A capable agent working on your behalf that makes mistakes, follows an injected instruction, or optimises for finishing the task over following the process. Not a remote attacker and not a malicious local user.

| Threat | Gate | Stops | Does not stop |
|---|---|---|---|
| T1 Agent opens a PR that skips review | `gh-pr-create-gate` | from the agent's Bash tool: `gh pr create`/`gh pr new` without `--draft`; any non-plain command that mentions them (chains, wrappers, substitutions, heredocs, variables); PR creation through `gh api` | a shell alias, function or script that runs `gh`; a pre-existing `gh` alias; a program that runs a command string and is not on the gate's list; the web UI; `curl` or other tools |
| T2 Agent merges unreviewed or changed code | `gh-pr-merge-gate` | merging a draft; merging while GitHub's PR head lags the branch tip (commits would be dropped); more than one PR or repository; any non-plain command that mentions a merge; merging through `gh api` | a merge of a commit other than the one reviewed (pin it with `--match-head-commit`); a shell alias, function or script; a pre-existing `gh` alias; the web UI; `curl` |
| T3 Agent weakens its own guardrails | `protect-gate-pages` | Edit, Write and NotebookEdit on protected paths, by any spelling of the same file | writes through the Bash tool; creating the unlock marker from Bash |
| T4 Agent works on unprefixed branches | `enforce-branch-prefix` | branch creation through common `git` forms | unusual quoting or aliases (by design this gate lets errors through) |
| T5 A hook crashes or hangs and the action proceeds | all security hooks | exit codes other than 0 and 2, and timeouts, block (`onFailure: "block"`); a missing `jq` is a deny | a hook that prints malformed output and exits 0; the hooks here never do |

## Assumptions

- Claude Code 2.1.295 or later, so `onFailure` is honoured.
- `jq`, `python3` and `gh` on `PATH` are the real tools. A compromised `PATH` defeats every gate.
- Repository branch rules on the server back up T1 and T2. The hooks are the fast local layer, not the only one.

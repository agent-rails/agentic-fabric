# fabric-gates

Hooks that keep a Claude Code agent inside a review-first git workflow. They run on the agent's tool calls only; commands you type in your own terminal are never affected.

## Install

```sh
claude plugin marketplace add agent-rails/agentic-fabric
claude plugin install fabric-gates@agentic-fabric
```

Requires Claude Code 2.1.295 or later (the hooks use `onFailure: "block"`), plus `bash`, `jq`, `python3` and `gh` on `PATH`.

## What runs

Every hook reads the tool call's JSON on stdin and either prints a deny decision or prints nothing.

| Hook | Event and matcher | Denies when | If the hook itself fails | Reads | Writes | Network |
|---|---|---|---|---|---|---|
| `gh-pr-create-gate.sh` | PreToolUse, `Bash` | `gh pr create` or `gh pr new` without `--draft`/`-d`, or with `--draft=false`; any command that mentions them but is not one plain invocation; creating a PR through `gh api` | blocks the call; a missing `jq` or a parser failure is a deny | the command | decision log | none |
| `gh-pr-merge-gate.sh` | PreToolUse, `Bash` | `gh pr merge` on a draft PR, naming more than one PR or repository, or while GitHub's PR head lags the branch tip; any command that mentions it but is not one plain invocation; merging through `gh api` | blocks the call; a missing `jq` or a parser failure is a deny | the command; `gh pr view` / `gh api` for the PR | decision log | GitHub API via `gh` |
| `enforce-branch-prefix.sh` | PreToolUse, `Bash` | a `git checkout -b/-B/--orphan`, `switch -c/-C/--create/--orphan`, `worktree add` (with `-b`, or a new branch named after the path) or `branch <name>` whose name lacks `branch_prefix`, or any branch creation while `branch_prefix` is unset; heredoc bodies are ignored, but a `<<` inside quotes or a comment is not a heredoc | lets the call run (a naming convention, not a security boundary) | the command; settings | decision log | none |
| `protect-gate-pages.sh` | PreToolUse, `Edit\|Write\|NotebookEdit` | an edit to a protected path without a fresh unlock | blocks the call | the target path; settings | decision log | none |

Protected by default: `~/.claude/settings.json`, `~/.claude/settings.local.json`, `~/.claude/scripts`, `policies`, `agents`, `rules`, `skills`, `plugins` (installed plugin code and data), `~/.config/agentic-fabric`, and any `evals/review-convergence/` directory. Paths are compared by file identity (device and inode), so `~`, `..`, case, Unicode and symlink spellings of the same file are the same case.

To edit a protected path on purpose, run `touch ~/.claude/gate-unlock` in your own terminal and retry within the unlock window.

The decision log is `gate-decisions.jsonl` in the plugin's data directory. Each line holds the hook, the decision, a reason code, the session and tool-use IDs and a SHA-256 of the payload. It holds no command text or file content, except that `protect-gate-pages` records the protected path it matched. It rotates to `gate-decisions.jsonl.1` once it reaches 5 MB, so it never grows without bound.

## Settings

| Option | Default | Meaning |
|---|---|---|
| `branch_prefix` | none (required) | Prefix every agent-created branch must carry, for example `me/`. |
| `protected_paths` | empty | Extra comma-separated paths relative to your home directory, for example `notes/review-rubric, standards/review.md`. Each is protected as a directory tree and as a file. An absolute path or `..` makes every protected-path check fail closed until fixed. |
| `gate_unlock_minutes` | 15 | How long the unlock marker is honoured. Clamped to 1-60. |

Set them when you enable the plugin, or in `~/.config/agentic-fabric/config.json` under `"fabric-gates"`. See [CONFIG](../../docs/CONFIG.md).

## Limits

- The hooks see tool calls, not intent. An agent with the Bash tool can still write a protected file through the shell or create the unlock marker. The gate stops accidental and silent drift; it is not a sandbox.
- The PR gates check only the plain form: one `gh pr create|new|merge` invocation on its own, parsed like a shell would, flag values included. A command that mentions one of them inside `&&`, `;`, a pipe, a subshell, `$(...)`, a heredoc, an environment prefix, `cd`, or a wrapper such as `bash -c`, `eval`, `env` or an interpreter is denied with a request to run it on its own. So `git push && gh pr create --draft` is denied: run the two commands separately. A heredoc in such a command is denied too; write a PR body to a file with an editor tool and pass `--body-file`. See [decision 0005](../../docs/decisions/0005-plain-form-pr-gates.md).
- What still gets past them: a shell alias or function that hides `gh`, a script file that runs it, a `gh` alias defined before the gate was installed, a program not on the gate's list that runs a command given as a string, and tools other than `gh` (the web UI, `curl`). Server-side branch rules are the backstop.
- The merge gate checks that GitHub's PR head matches the branch tip. It does not know which commit was reviewed; pin that with `gh pr merge --match-head-commit <sha>`.
- A hook that prints malformed output and exits 0 does not block (observed on Claude Code 2.1.301). Every error path here prints a valid decision or exits non-zero.

## Tests

```sh
bash tests/gates.test.sh
bash tests/gh-pr-merge-gate.test.sh
```

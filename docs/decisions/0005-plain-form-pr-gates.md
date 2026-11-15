# 0005: The PR gates check only the plain form of a command

Status: accepted.

## Decision

The create and merge gates check a command only when it is one plain `gh pr create|new|merge` invocation, parsed with shell quoting rules and with every flag value accounted for. Any other command in which `gh` (or a variable) runs `pr create|new|merge` as separate words is denied: chains, pipes, subshells, brace groups, `if`/`for`/`!`, `find -exec`, prefixes such as `caffeinate` or `sudo`, `$(...)`, heredocs, environment prefixes and variables. A shell, interpreter or other program given the command as a string (`bash -c`, `eval`, `python -c`, `awk`, `ssh`, a `git -c alias.x='!...'`) is denied when the string mentions it. Any heredoc or here-string in a command that mentions the subcommand is denied, whatever it feeds. So is any command in which `gh`, `pr` or the subcommand word is built by shell expansion (`cre${x}ate`, `{create,}`, `g${u}h`, `$(...)` inside the word); `$` and braces elsewhere, as in `gh pr view "$N"` or `gh api repos/{owner}/{repo}`, are unaffected. Creating or merging a pull request through `gh api`, and a `gh alias` that expands to one of these subcommands, are denied as well.

## Why

The gates used to search the command text for the subcommand and its flags. A cross-vendor review then got past them with ordinary shell: `bash -c '...'`, a heredoc on the same line, a second merge chained after a checked one, and a flag value read as the PR number. Each fix by pattern invited the next form, which is the keyword-list anti-pattern ([patterns](../../patterns/keyword-list-as-security-control.md)). Accepting one shape the parser can read completely, and refusing every executable mention that is not that shape, removes the per-form patching. One list remains: the programs that run a command given as a string. That list is the residual risk and is stated below.

## Rejected

- Keep matching text and patch each bypass. Every review found new forms.
- Treat the gates as advisory and rely on server rules alone. That leaves no local stop for an agent that skips review.

## Consequences

- Agents run `git push` and `gh pr create --draft` as two commands.
- A PR body goes in a file written with an editor tool and passed with `--body-file`, not through a heredoc.
- An attempt to allow quoted heredoc bodies as data was reverted after a cross-vendor review got 13 executable forms past it (a marker inside quotes or a comment, a pipe to `bash`, prefixes, capture into a variable). Telling data from code inside shell text is the open-ended problem this rule exists to avoid.
- An unknown `gh` flag is denied until the gate learns it.
- A mention inside the arguments of an ordinary program, such as a commit message, is data and is allowed.
- Not covered: a shell alias, function or script file that runs `gh`; a `gh` alias defined before the gate was installed; a program not on the list that runs a command given as a string. Server-side branch rules back the gates up.

## Evidence

Reproduced: `plugins/fabric-gates/tests/gates.test.sh` and `tests/gh-pr-merge-gate.test.sh` hold each form that three cross-vendor review cycles and a fix-verification pass executed against the gates, each as a case an earlier version allowed, plus everyday commands that must stay allowed.

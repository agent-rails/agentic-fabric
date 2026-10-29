# Threat model

What this stack protects, from whom, with which controls, and what is left over. It is written for someone deciding whether to install it. Read [SECURITY.md](../SECURITY.md) for reporting and [DESIGN-PRINCIPLES.md](DESIGN-PRINCIPLES.md) for why hooks come before prompts.

Status labels: **tested** means a test in `scripts/` fails without the control; **read** means the behaviour comes from reading the code or wiring, not from running it; **observed** means I ran it once on one machine, with the version stated. Anything unlabelled is a claim, not a result.

## Scope

The bundle is prompts, skills and shell/Python hooks that you copy into `~/.claude/`. It runs on your machine, as you, with the credentials your shell can reach (`gh`, cloud CLIs, Slack through a connector). It is not a service and not a sandbox. The threat model covers the agent acting on your behalf, not other users of the machine.

## Assets

- Credentials and files reachable from the agent's shell.
- Repository state that is hard to undo: merging, marking a PR ready, force-pushing.
- Outbound messages: Slack, email, PR comments.
- The review rubric and shared conventions that grade the agent's own work.
- Source code that is sent to a second model vendor during cross-vendor review.
- The wiki pages the agents read as memory.

## Trust boundaries

1. User to agent. The user is the orchestrator; outbound actions are meant to need a human decision.
2. Agent to untrusted content: PR diffs, issue text, web pages, chat messages, fetched files. This is where prompt injection enters.
3. Machine to the second vendor: cross-vendor review sends context to another company's servers.
4. Repository to adopter: installing the bundle means running shell scripts and prompts written by someone else.
5. Agents to wiki memory: what one session writes, a later session trusts.

## Threats, controls and what remains

| # | Threat | Control today | Status | Remaining risk |
|---|---|---|---|---|
| T1 | The agent merges, or opens a non-draft PR, by mistake | PR create and merge gates parse the command and deny the unsafe form, including `--repo`, API calls and `bash -c`; unparsable commands are denied | tested | `gh` inside a quoted command substitution, `eval`, shell variables and aliases, scripts that call `gh`, and other GitHub clients such as `curl` are not seen |
| T2 | The agent sends a message or reply without approval | The triage flow asks `[Send]/[Edit]/[Skip]` | read, prompt only | No hook enforces it. A model that skips the step is not stopped |
| T3 | Prompt injection through untrusted content | Review prompts wrap captured output in nonce-delimited untrusted blocks; the write scan pattern-matches written content | read | The agent still has a shell. Delimiters and a regex do not stop a model that follows an instruction found in a diff or web page |
| T4 | The agent edits the rubric that grades it | Gate-page protection denies Edit/Write to those paths unless a human creates an unlock marker; fails closed without `jq` | read | Only the Edit, Write and NotebookEdit tools pass through it. A shell redirect does not |
| T5 | Source or secrets leave the machine through the second vendor | Cross-vendor review is optional and runs the vendor CLI with a read-only sandbox | observed | The read-only sandbox blocked writes but not reads outside the repository (Codex CLI 0.160.0, macOS: a file in a sibling directory was read). Anything readable and quoted in the answer can leave |
| T6 | A malicious or compromised copy of this repo or a fork | Documentation asks you to read hooks before wiring them; a skill scanner exists | read | No signed releases, no pinned versions, install is a manual copy. A hook is code that runs with your privileges |
| T7 | Memory poisoning: a bad wiki page steers later sessions | Convention pages are protected (T4); scribes write the rest | read | Non-convention pages are writable by agents and trusted on the next read |
| T8 | A hook fails and quietly allows the action | See the table below | tested for the PR gates, the write-scan dependency check and the installer check; read for the rest | The convention hooks fail open on purpose |
| T9 | Secrets in written content or logs | The write scan logs but does not block credential words and long base64 strings | read | No secret-shape detector: assignments such as `password=` or `api_key=` match no rule, as the policy file itself says |

### Failure posture of each hook

| Hook | If it errors or cannot parse | Why |
|---|---|---|
| PR create gate, PR merge gate | deny | these guard actions that are hard to reverse |
| Write-content scan | deny (also when `guard` or `jq` is missing, which blocks every Write and Edit) | content that cannot be checked should not land |
| Gate-page protection | deny for protected paths when `jq` is missing; allow otherwise, with a warning | narrow fail-closed |
| Branch-prefix hook | allow | a naming convention, not a boundary |
| Resume-constraint hook | allow | must not wedge a resume |

`scripts/doctor.sh` checks that the dependencies the fail-closed hooks need are present before you restart.

## Non-goals

- Stopping an agent, or an injected instruction, that is deliberately working around the hooks. These controls reduce accidents.
- Isolating the agent from your files and network. Use an OS or container sandbox for that.
- Multi-user or multi-tenant use.

## What would change this model

- Hooks that cover the shell tool for the same effects (for example wrapping `gh` itself rather than inspecting the command).
- Signed, versioned releases and a pinned install path.
- A measured false-negative rate for the write scan and the review cascade. See [EVALUATION.md](EVALUATION.md).

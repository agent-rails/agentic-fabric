# agentic-fabric

What one maintainer learned running Claude Code agents on real repositories, written up as patterns, workflows and decisions, with Claude Code plugins that enforce the parts a hook can enforce.

Status: `0.1.0`. One plugin so far; the rest of the stack (subagent model routing, review loops with a seeded-defect eval, zero-token workflow metrics, engineering standards) is planned as further plugins and lands only when it meets the same bar.

## What was learned

- [Patterns](patterns/README.md): 16 pattern and anti-pattern pages, such as hooks that claim to fail closed and do not, reviewers whose stalled passes get logged as clean, keyword lists treated as security controls, and eval scorers that make every number lie.
- [Workflows](workflows/README.md): review-first pull requests, cross-vendor review with bounded cycles, turning escaped defects into eval cases, and measuring from existing logs before adding instrumentation.
- [Decisions](docs/decisions/README.md): why the rules are hooks, why hooks fail closed, why customisation goes through settings, how releases are made. Each record lists the options it rejected.

## Evidence

Every pattern and workflow page states the tier of its evidence:

- Reproduced: a test or script in this repository produces the result. Run it yourself.
- Observed: an aggregate from the maintainer's own operating logs, stated with its window, sample size and method. The raw logs stay private and no repository, pull request or person is named. Most samples are small, one maintainer on one machine; treat them as field notes, not benchmarks.

## Enforcement: plugins

| Plugin | What it does | Evidence |
|---|---|---|
| [fabric-gates](plugins/fabric-gates/README.md) | Draft-first PRs; no merge of a draft, or of a PR whose GitHub head lags its branch tip, or when PR state cannot be read; a branch prefix; Edit/Write edits to the enforcement layer only after a human unlock (writes through the Bash tool are outside its reach). Enforces part of [review-first pull requests](workflows/review-first-pull-requests.md). | Reproduced: the shell suites in `plugins/fabric-gates/tests/`; [onfailure-check.sh](docs/evidence/onfailure-check.sh) reproduces the fail-closed behaviour. |

## Install

```sh
claude plugin marketplace add agent-rails/agentic-fabric
claude plugin install fabric-gates@agentic-fabric
```

Pin a release with `claude plugin marketplace add agent-rails/agentic-fabric@v0.1.0`. Requires Claude Code 2.1.295 or later.

## Principles

- Hard rules live in hooks, not prompts. A prompt is a request; a hook is a decision the agent cannot talk its way past. See [decision 0001](docs/decisions/0001-hooks-for-hard-rules.md).
- A hook that cannot decide refuses. Every security hook sets `onFailure: "block"` and turns its own errors into a deny that names the fix. See [decision 0002](docs/decisions/0002-fail-closed-hooks.md).
- Customise through settings, never by editing shipped files. See [CONFIG](docs/CONFIG.md) and [decision 0003](docs/decisions/0003-settings-not-edits.md).
- Evidence is labelled: reproduced by a test or script here, or observed in operation with its window, sample size and method. See [Evidence](#evidence).

## What this is not

- Not a sandbox. Hooks see tool calls; an agent with shell access can still act outside them. The [threat model](docs/THREAT_MODEL.md) lists what each gate stops and what it does not.
- Not a prompt collection. Agents and skills ship only where a test or an eval measures them.
- Not a benchmark. Observed numbers describe one maintainer's operation and say so.

## Contributing

Issues and discussions are open. Pull requests are welcome as proposals; changes are ported by the maintainer and published by the release process, with credit. See [CONTRIBUTING](CONTRIBUTING.md) and [decision 0004](docs/decisions/0004-maintainer-ported-releases.md).

Security reports: [SECURITY](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

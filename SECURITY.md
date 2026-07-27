# Security policy

`agentic-fabric` is a collection of prompts, rules, and shell hooks that drive a Claude Code agent with real tool access (shell, `git`, `gh`, and optionally Slack and a second-vendor CLI). The main risk surface is not a running service but the instructions and hooks you copy into `~/.claude/` and execute locally.

## Before you run

- Read the agent definitions (`agents/`), skills (`skills/`), and hook scripts (`scripts/`) before copying them into your config.
- Replace all placeholders (see the README) so hooks resolve to your paths, not stale ones.
- Keep outbound actions (message sends, PR merges) human-gated, as shipped.

## Reporting a vulnerability

If you find a security issue — for example a hook that can be bypassed, a prompt that could exfiltrate secrets, or an unsafe default — please report it privately rather than opening a public issue:

- Use GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) on this repository (Security tab → "Report a vulnerability"), or
- Open a minimal issue asking for a private contact channel, without disclosing details.

Please include: what you found, how to reproduce it, and the potential impact. We'll acknowledge and work on a fix; please allow reasonable time to remediate before any public disclosure.

## Scope

In scope: the hooks in `scripts/`, unsafe defaults in agent/skill prompts, and placeholder-handling that could leak secrets or paths.

Out of scope: vulnerabilities in Claude Code, the `gh` CLI, the Codex CLI, or Slack themselves — report those to their respective maintainers.

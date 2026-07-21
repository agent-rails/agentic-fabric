# Contributing

Thanks for looking. This is a personal, dogfooded multi-agent stack for Claude Code — shared so others can lift ideas and patterns, not a turnkey product. Read this before opening a PR.

## Before you run anything

These files are prompts and hooks that drive an agent with tool access on your machine. Treat them as code you're about to execute, because that's what they are.

- Review every hook in `scripts/` before wiring it into `~/.claude/settings.json`. Hooks can deny or gate tool calls; understand what each one does.
- Replace every placeholder before use: `grep -rn 'your-org\|youralias\|YOUR_SLACK\|you@example.com' .`
- Never commit real secrets, tokens, org names, internal IDs, or personal data. The repo ships sanitized; keep it that way.
- The agent definitions assume outbound actions (send / merge / push) stay human-gated. Don't remove those gates without understanding [ADR-0006](docs/decisions/0006-outbound-human-gate.md).

## What's welcome

- Bug fixes in hooks/scripts (with the failure mode named — see the "fail loud" principle).
- New skills or agent definitions that follow the [orchestration patterns](shared-wiki/orchestration-patterns.md). A new persona that calls another persona, or a router persona, will be declined — see the anti-patterns.
- Docs improvements: architecture, principles, ADRs (`docs/`).
- Sanitization fixes (a placeholder that leaked a real value).

## Design guardrails (read first)

Changes are measured against the documented design:

- [docs/DESIGN-PRINCIPLES.md](docs/DESIGN-PRINCIPLES.md) — the load-bearing whys.
- [docs/decisions/](docs/decisions/) — the ADRs. If a PR reverses one, it needs a new ADR arguing why, not a silent change.
- [shared-wiki/orchestration-patterns.md](shared-wiki/orchestration-patterns.md) — endorsed patterns and anti-patterns for composing agents.
- [shared-wiki/agent-principles.md](shared-wiki/agent-principles.md) — smallest change addressing the root cause; verify before declaring done; state non-goals.

## PR workflow

1. Branch from `main`.
2. Keep diffs small and atomic — one concern per PR.
3. Open a **draft** PR first (`gh pr create --draft`). Mark ready after self-review.
4. In the description, state what you changed, why, and what you deliberately did NOT change (non-goals).
5. Conventional commits: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `style`, `perf`. Subject in imperative mood, lowercase, no trailing period.

## What this project is not

- Not a supported product. No SLA, no roadmap commitments.
- Not vendor-neutral by construction — it targets Claude Code and (for cross-vendor review) a second model family. Portability is best-effort.
- Not a place for secrets or org-specific config. Fork privately for that.

## License

By contributing, you agree your contributions are licensed under the [Apache License 2.0](LICENSE).

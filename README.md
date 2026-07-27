# agentic-fabric

A personal multi-agent stack for Claude Code: communication triage, PR review with institutional memory, cross-vendor verification, automated reporting, and the hooks/rules that keep it honest.

Built and dogfooded daily over months of real DevOps/SRE work. Sanitized for portability — org names, IDs, and internal references are placeholders (`your-org`, `YOUR_SLACK_USER_ID`, `youralias/`, ...); grep for them when adapting.

## What's inside

| Dir | Contents |
|-----|----------|
| `agents/` | Agent definitions. Two families plus build/QA roles: **triage-agent** (chief-of-staff: multi-channel triage, tiered classification + routing verdicts, draft replies, wiki memory) with fetcher/scribe/reporter subagents; **pr-reviewer** (PR review synthesizer: evidence-calibrated severity, review-cycle convergence bounds, wiki-backed repo/author memory) with fetcher/scribe, **cross-vendor-reviewer** (cross-vendor reviewer via a second model family) and **patch-drafter** (cross-vendor patch drafter). Plus orchestrator, researcher, implementer, tester, debugger, architect(s), senior-qa, context-manager. |
| `agents/triage-reporter/` | launchd-driven daily/weekly report automation: `run.sh` (21:00 cron), `catchup.sh` (4h backfill), `session-drain-check.sh` (SessionStart hook that delivers queued reports when an interactive session can reach Slack — headless runs can't reach OAuth connectors). |
| `skills/` | Slash-command workflows: `/triage`, `/daily-report`, `/weekly-report`, `/standup`, `/review-pr`, `/draft-pr-fixes`, `/self-review`, `/pr-sizer`, `/workflow-miner`, `/memory-lint`, `/wiki-lint`, `/ci-investigation`, session management, delegation patterns, and more. |
| `commands/` | Older-style command prompts (PR summary, design doc, prompt-writing guide, standup). |
| `scripts/` | PreToolUse hooks: branch-prefix enforcement (`youralias/` gate), PR-create gate, wiki gate-page protection, skill scanner. |
| `rules/` | Global rules files (general, git, planning, prompting, python, typescript, testing). |
| `shared-wiki/` | Cross-agent convention pages: agent principles, search discipline, orchestration patterns (incl. the persona-to-pattern mapping). |
| `wikis/triage-agent/`, `wikis/pr-reviewer/` | The wiki *machinery* for each agent's persistent memory: purpose, schema, page templates, convention pages, helper scripts. Wiki *data* (people, logs, reviews, reports) deliberately excluded. |
| `launchd/` | macOS LaunchAgent plists for the report automation. |
| `docs/settings.hooks.example.json` | Hook wiring for `~/.claude/settings.json` (commands are placeholders). |

## Design principles

For the internals, the whys, and the decisions behind them, see [`docs/`](docs/) — [architecture](docs/ARCHITECTURE.md), [design principles](docs/DESIGN-PRINCIPLES.md), and the [decision records](docs/decisions/). The short list:

- Judgment on the big model, mechanics on cheap ones (haiku fetchers, sonnet scribes)
- Hooks over prompts for anything that must not be skipped
- Wikis as persistent memory — every session reads from and writes back to them
- Evidence-calibrated review severity: unverified BLOCKER claims get downgraded
- Cross-vendor cascade for reasoning diversity on security-critical paths
- Outbound actions (sends, merges) always human-gated

## Install sketch

1. Copy `agents/`, `skills/`, `commands/`, `scripts/`, `rules/`, `shared-wiki/` content into `~/.claude/`
2. Seed `~/triage-agent/` and `~/pr-reviewer/` from `wikis/` (schema + templates; wikis fill themselves through use)
3. Replace every placeholder (`grep -r "your-org\|youralias\|YOUR_SLACK\|you@example.com" .`)
4. Wire hooks per `docs/settings.hooks.example.json`; load launchd plists if you want scheduled reports

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). These are prompts and hooks that drive an agent with tool access — review before you run them, and keep outbound actions human-gated.

## License

[Apache License 2.0](LICENSE). Portions of `shared-wiki/orchestration-patterns.md` are adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT) — see [NOTICE](NOTICE).

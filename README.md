# agentic-fabric

A personal multi-agent stack for Claude Code: communication triage, PR review with institutional memory, cross-vendor verification, automated reporting, and the hooks/rules that keep it honest.

Built and dogfooded daily over months of real DevOps/SRE work. Sanitized for portability — org names, IDs, and internal references are placeholders (`your-org`, `YOUR_SLACK_USER_ID`, `youralias/`, ...); grep for them when adapting. The agent names are placeholders too — see [Placeholders](#placeholders).

## What's inside

| Dir | Contents |
|-----|----------|
| `agents/` | Agent definitions. Two families plus build/QA roles: **your-triage-agent** (chief-of-staff: multi-channel triage, tiered classification + routing verdicts, draft replies, wiki memory) with fetcher/scribe/reporter subagents; **your-pr-reviewer** (PR review synthesizer: evidence-calibrated severity, review-cycle convergence bounds, wiki-backed repo/author memory) with fetcher/scribe, **your-cross-vendor-reviewer** (cross-vendor reviewer via a second model family) and **your-patch-drafter** (cross-vendor patch drafter). **your-same-vendor-reviewer** is the automatic fallback for your-cross-vendor-reviewer when no second-vendor CLI is reachable — a fresh, unprimed, same-model adversarial pass, explicitly self-labeled `cross_vendor: false` so it's never mistaken for real cross-vendor signal. Plus orchestrator, researcher, implementer, tester, debugger, architect(s), senior-qa, context-manager. |
| `agents/your-triage-reporter/` | launchd-driven daily/weekly report automation: `run.sh` (21:00 cron), `catchup.sh` (4h backfill), `session-drain-check.sh` (SessionStart hook that delivers queued reports when an interactive session can reach Slack — headless runs can't reach OAuth connectors). |
| `skills/` | Slash-command workflows: `/triage`, `/daily-report`, `/weekly-report`, `/standup`, `/review-pr`, `/draft-pr-fixes`, `/self-review`, `/pr-sizer`, `/workflow-miner`, `/memory-lint`, `/wiki-lint`, `/ci-investigation`, session management, delegation patterns, and more. `/workflow-miner` also mines tool-call frequency from Claude Code's own session logs (name+timestamp only, never content) as a lightweight efficiency signal, alongside its recurring-task-pattern ladder. |
| `commands/` | Older-style command prompts (PR summary, design doc, prompt-writing guide, standup). |
| `scripts/` | PreToolUse hooks: branch-prefix enforcement (`youralias/` gate), PR-create gate, wiki gate-page protection, skill scanner, pre-write malicious-content scan. |
| `policies/` | Declarative policy for the pre-write content scan (`write-content-scan.yaml`), evaluated by [agent-guard](https://github.com/agent-rails/agent-guard) — a separate, real, deterministic tool-call-authorization library, not part of this bundle. |
| `rules/` | Global rules files (general, git, planning, prompting, python, typescript, testing). |
| `shared-wiki/` | Cross-agent convention pages: agent principles, search discipline, orchestration patterns (incl. the persona-to-pattern mapping). |
| `wikis/your-triage-agent/`, `wikis/your-pr-reviewer/` | The wiki *machinery* for each agent's persistent memory: purpose, schema, page templates, convention pages, helper scripts. Wiki *data* (people, logs, reviews, reports) deliberately excluded. |
| `launchd/` | macOS LaunchAgent plists for the report automation. |
| `docs/settings.hooks.example.json` | Hook wiring for `~/.claude/settings.json` (commands are placeholders). |

## How it fits together

```mermaid
flowchart TD
    user["USER (orchestrator)"]
    harness["Claude Code: rules + hooks + shared-wiki"]
    user -->|slash command| harness
    harness --> your-triage-agent["your-triage-agent: triage / reports"]
    harness --> your-pr-reviewer["your-pr-reviewer: PR review synthesizer"]
    your-pr-reviewer -.cross-vendor.-> your-cross-vendor-reviewer["your-cross-vendor-reviewer / your-patch-drafter (Codex CLI)"]
    your-cross-vendor-reviewer -.fallback if unavailable.-> your-same-vendor-reviewer["your-same-vendor-reviewer (same model family)"]
    your-triage-agent <--> vwiki[("~/your-triage-agent wiki")]
    your-pr-reviewer <--> swiki[("~/your-pr-reviewer wiki")]
```

Full diagrams and control flow: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Prerequisites

Required for the core triage + PR-review path:

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** — the whole stack layers on it.
- **[`gh` CLI](https://cli.github.com/)**, authenticated (`gh auth login`) — PR fetch, review, and the PR-create gate.
- **`git`** — branches, wikis, PRs.
- **`grep`** and **`python3`** — used by the branch-prefix hook (`scripts/enforce-branch-prefix.sh` → `.py`).
- **`jq`** — used by the `gh-pr-create-gate.sh` and `protect-gate-pages.sh` hooks.

Optional, per feature:

- **macOS** — only for the launchd daily/weekly report automation (`launchd/`, `agents/your-triage-reporter/run.sh` uses BSD `date`).
- **[OpenAI Codex CLI](https://github.com/openai/codex)** — only for the cross-vendor reviewer/patch-drafter (`your-cross-vendor-reviewer`, `your-patch-drafter` run `codex exec --sandbox read-only`). Skip if you don't use `/review-pr`'s cross-vendor cascade or `/draft-pr-fixes` — `your-same-vendor-reviewer` runs automatically in its place either way, so cross-vendor review is a quality upgrade, not a hard dependency.
- **A Slack app / MCP connector** — only for report delivery and Slack triage (`/daily-report`, `/triage`). Read-only Slack search plus a send tool on the main thread.
- **[agent-guard](https://github.com/agent-rails/agent-guard)** (`pipx install "toolcall-authz[yaml] @ git+https://github.com/agent-rails/agent-guard.git"`, then `pipx inject toolcall-authz pyyaml`) — only for `scripts/scan-write-content.sh`, the pre-write malicious-content scan. Skip if you don't wire that hook; the rest of the bundle has no dependency on it.

Not required: no Node/npm, no build step — these are prompts, shell hooks, and markdown.

## Quickstart

Minimal path to a working triage + PR-review setup. Run from the repo root after cloning. Review the prompts and hooks before you run them.

```bash
# 1. Copy the agent stack into your Claude Code config
cp -R agents skills commands scripts rules shared-wiki policies ~/.claude/
chmod +x ~/.claude/scripts/*.sh ~/.claude/scripts/*.py

# 2. Seed the agent wikis (machinery only; data fills itself through use)
mkdir -p ~/your-triage-agent ~/your-pr-reviewer
cp -R wikis/your-triage-agent/. ~/your-triage-agent/
cp -R wikis/your-pr-reviewer/. ~/your-pr-reviewer/

# 3. Find every placeholder you must replace (see table below)
grep -rn "your-org\|youralias\|YOUR_SLACK\|you@example.com\|/Users/youruser" ~/.claude
```

4. **Replace placeholders** in your `~/.claude` copy (not the repo). See the table below.

5. **Wire the hooks.** Merge `docs/settings.hooks.example.json` into `~/.claude/settings.json`, swapping every `/Users/youruser/...` path for your real home and replacing the `your-pretool-hook` / `your-stop-guard` placeholders with your own commands (or removing those entries if you don't have them).

Restart Claude Code so it picks up the new agents, skills, and hooks. Then run **Verify** below.

Optional add-ons (do after the core path works): [report automation](#optional-report-automation-macos) and [Slack delivery](#optional-report-automation-macos).

## Placeholders

Replace in your `~/.claude` copy before use. The grep in step 3 finds all of them.

| Placeholder | Where | Required? |
|-------------|-------|-----------|
| `/Users/youruser/...` | `settings.hooks.example.json`, `launchd/*.plist` | **Required** — must match your real `$HOME`, or hooks/cron won't resolve. |
| `youralias/` | `scripts/enforce-branch-prefix.py` (`REQUIRED_PREFIX`) | **Required if** you enable the branch-prefix hook — set it to your own branch namespace. |
| `your-org` | rules, wiki machinery, examples | Required if referenced in your workflows; otherwise cosmetic. |
| `you@example.com` | rules, examples | Optional — cosmetic unless a workflow depends on it. |
| `YOUR_SLACK_USER_ID` / `user_slack.md` | Slack triage + report delivery | **Required if** you use Slack (`/triage`, `/daily-report`); otherwise skip. |
| `your-pretool-hook`, `your-stop-guard` | `settings.hooks.example.json` | Optional — your own custom hooks; remove the entries if unused. |

## Verify your install

After restarting Claude Code:

- **Skills load** — open the slash-command menu (`/`) and confirm `/triage`, `/review-pr`, `/self-review` appear. `/help` lists available commands.
- **Agents load** — the agent names in `agents/` (your-triage-agent, your-pr-reviewer, ...) resolve when referenced.
- **Hooks fire** — the branch-prefix gate is the easiest check: ask the agent to create a branch that does *not* start with your alias (e.g. `git checkout -b test-branch`). The hook should block it with a message telling you to use your `<alias>/` prefix. A `<alias>/...` branch should succeed.
- **PR gate** — asking the agent to run `gh pr create` without `--draft` should be denied with a "Review-first PR workflow required" message.

If a hook doesn't fire, re-check the paths in `~/.claude/settings.json` (step 5) and that the scripts are executable (`chmod +x`).

## How to use

Once installed, drive the stack through slash commands:

| Command | When to use |
|---------|-------------|
| `/triage` | Morning multi-channel sweep — classify email/Slack, draft replies (sending stays human-gated). |
| `/review-pr <url>` | Review a PR with the your-pr-reviewer synthesizer; cascades cross-vendor peers on security/arch paths. |
| `/self-review` | Review your own local branch before opening a PR. |
| `/draft-pr-fixes` | After a review, have the cross-vendor drafter propose patches for cherry-pick (never auto-applied). |
| `/pr-sizer` | Check whether a PR is too large and get a split plan. |
| `/daily-report`, `/weekly-report` | Generate an activity report from GitHub/Slack; delivered via Slack DM. |
| `/standup` | Daily standup summary from commits + GitHub activity. |
| `/ci-investigation` | Investigate failing CI on a PR. |
| `/wiki-lint`, `/memory-lint`, `/workflow-miner` | Maintenance — health-check wikis/memory and mine recurring tasks. |

## Optional: report automation (macOS)

The daily/weekly reports run on a launchd schedule and deliver via Slack.

1. Copy the plists in `launchd/` to `~/Library/LaunchAgents/`, replacing every `/Users/youruser/...` path with your real home.
2. Load them with `launchctl` (macOS LaunchAgents).
3. Reports generate offline and queue; delivery is a separate step handled by the main (interactive) session via the `SessionStart` drain hook, so headless runs never silently drop a report. See `agents/your-triage-reporter/`.

Slack delivery needs a Slack app / MCP connector with a send tool available on the main thread, plus your Slack user ID wired per the `YOUR_SLACK_USER_ID` placeholder.

## Design principles

For the internals, the whys, and the decisions behind them, see [`docs/`](docs/) — [architecture](docs/ARCHITECTURE.md), [design principles](docs/DESIGN-PRINCIPLES.md), and the [decision records](docs/decisions/). The short list:

- Judgment on the big model, mechanics on cheap ones (haiku fetchers, sonnet scribes)
- Hooks over prompts for anything that must not be skipped
- Wikis as persistent memory — every session reads from and writes back to them
- Evidence-calibrated review severity: unverified BLOCKER claims get downgraded
- Cross-vendor cascade for reasoning diversity on security-critical paths, with a same-vendor fallback so a fresh adversarial pass still runs when no second vendor is reachable
- Reuse a deterministic policy engine (agent-guard) for the write-content scan rather than a second bespoke heuristics implementation — one tested engine, two call sites (tool-call authorization and pre-write content)
- Outbound actions (sends, merges) always human-gated

## Customizing this stack

The goal is a layer-0 set of building blocks, not a locked black box — adopt what's useful, replace or delete the rest, and build your own on top. Concretely, four things are already customization points, not just implementation details:

- **Agent names are placeholders, not identity.** Nothing in the stack hard-codes the shipped codenames (`your-pr-reviewer`, `your-triage-agent`, ...) — rename each family to whatever you call your own agents. See [Placeholders](#placeholders).
- **Agents are plain markdown, not compiled.** There's no plugin API to learn for behavior changes, because there's no runtime layer standing between you and the prompt — the prompt *is* the customization surface. Want `your-pr-reviewer` to check for something it doesn't today? Edit `agents/your-pr-reviewer.md` directly. No build step, no framework to fight.
- **Policy-driven behavior is externalized, not hardcoded in scripts.** `scan-write-content.sh` reads its ruleset from `policies/write-content-scan.yaml` via an overridable env var (`SCAN_WRITE_CONTENT_POLICY`) rather than embedding patterns in the shell script itself — swap in your own policy file without touching the hook. This is the pattern to follow for any new script you add: config as data, script as glue.
- **Hooks are a template to merge, not a config to apply as-is.** `docs/settings.hooks.example.json` is meant to be merged into your own `~/.claude/settings.json`, then edited — add hooks, remove the ones you don't want, reorder them. Nothing here assumes you'll run the full set.

If you build something new on top of this — a different reviewer cascade, a different wiki backend, a different policy engine — that's the intended use, not a deviation from it.

## Security

These are prompts and hooks that drive an agent with real tool access (shell, `git`, `gh`, Slack, and — if enabled — a second-vendor CLI that sends context to OpenAI servers). Treat them accordingly:

- **Review before you run.** Read the agent definitions, skills, and hook scripts before copying them into `~/.claude/`.
- **Keep outbound actions human-gated.** Message sends and PR merges are gated by design (see the PR-create draft gate and the `[Send]/[Edit]/[Skip]` triage flow); keep them that way.
- **Cross-vendor CLIs run read-only.** `your-cross-vendor-reviewer`/`your-patch-drafter` wrap `codex exec --sandbox read-only` and never write files — the orchestrator applies any patch under your permission model.

To report a vulnerability, see [SECURITY.md](SECURITY.md).
## Placeholders

Everything below is a placeholder to replace with your own values. The agent names ship as generic placeholders so you rename each family to whatever you call your own agents — nothing in the stack hard-codes the original codenames.

| Placeholder | Replace with | Required |
|-------------|--------------|----------|
| `your-org` | Your GitHub org / owner (used in repo URLs and paths) | Required |
| `youralias` | Your git branch prefix / short handle (branch-prefix hook) | Required |
| `YOUR_SLACK_USER_ID` | Your Slack user ID (for report/triage DMs) | Required-if-used |
| `you@example.com` | Your email address | Required-if-used |
| `your-triage-agent` | Rename to your own agent name — the triage / chief-of-staff agent | Required-if-used |
| `your-triage-fetcher` | Rename to your own agent name — triage data-fetcher subagent | Required-if-used |
| `your-triage-scribe` | Rename to your own agent name — triage wiki-scribe subagent | Required-if-used |
| `your-triage-reporter` | Rename to your own agent name — triage reporting subagent | Required-if-used |
| `your-pr-reviewer` | Rename to your own agent name — PR-review synthesizer agent | Required-if-used |
| `your-pr-review-fetcher` | Rename to your own agent name — PR-review data-fetcher subagent | Required-if-used |
| `your-pr-review-scribe` | Rename to your own agent name — PR-review wiki-scribe subagent | Required-if-used |
| `your-cross-vendor-reviewer` | Rename to your own agent name — cross-vendor (second model family) reviewer | Required-if-used |
| `your-same-vendor-reviewer` | Rename to your own agent name — automatic same-vendor fallback when the cross-vendor reviewer is unavailable | Required-if-used |
| `your-patch-drafter` | Rename to your own agent name — cross-vendor patch drafter | Required-if-used |

Env-var and structured-block names derive from the same base names (e.g. `YOUR_TRIAGE_AGENT_NO_DRAIN`, `YOUR_CROSS_VENDOR_REVIEWER_INPUT`, `YOUR_CROSS_VENDOR_REVIEWER_REVIEW`, `YOUR_PATCH_DRAFTER_DRAFT`) — rename them to match whatever you pick.

## Install sketch

1. Copy `agents/`, `skills/`, `commands/`, `scripts/`, `rules/`, `shared-wiki/` content into `~/.claude/`
2. Seed `~/your-triage-agent/` and `~/your-pr-reviewer/` from `wikis/` (schema + templates; wikis fill themselves through use)
3. Replace every placeholder (`grep -r "your-org\|youralias\|YOUR_SLACK\|you@example.com\|your-triage-\|your-pr-review\|your-cross-vendor-reviewer\|your-same-vendor-reviewer\|your-patch-drafter" .`) — see [Placeholders](#placeholders)
4. Wire hooks per `docs/settings.hooks.example.json`; load launchd plists if you want scheduled reports

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). These are prompts and hooks that drive an agent with tool access — review before you run them, and keep outbound actions human-gated.

## License

[Apache License 2.0](LICENSE). Portions of `shared-wiki/orchestration-patterns.md` are adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT) — see [NOTICE](NOTICE).

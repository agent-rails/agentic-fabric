---
name: security-signal-amplifier
description: Amplify external AI/MCP security advisories into the right channels for your org — summarize the advisory, cross-post to #security or the devops group DM, propose a concrete mitigation (rotation, sandbox, Snyk skill scanner, scoped identity), and drive the follow-up thread with devops + security peers. Use when the user spots an external AI/MCP security advisory, breach, or vulnerability and wants it socialized internally — trigger phrases include "security advisory", "MCP vulnerability", "amplify security signal", "share security advisory", "post to security channel", "Vercel breach", "malicious MCP", "AI supply chain", or pasting an advisory link asking "share this".
---

## When to use

- External AI/MCP security advisory surfaces (vendor bulletin, CVE, breach post, JPEG-embedded backdoor, supply-chain compromise) and the user wants it amplified internally.
- Concrete recent shape: Vercel/context.ai breach, Lazarus-AI/clearwing FFmpeg LLM scanner, malicious MCP servers, MCP JPEG payloads, Snyk skill scanner findings.
- User asks to "share this with security" or "ping devops about this advisory" with a link or excerpt.

## When NOT to use

| Situation | Use instead |
|-----------|-------------|
| General inbound classification across Slack/email/calendar | `triage` |
| Morning briefing, "what do I have" | `triage` |
| Drafting replies to inbound DMs unrelated to a security advisory | `triage` |
| Internal Wiz/Snyk finding triage on existing infra | `triage` (then standard incident flow) |
| End-of-day activity summary | `daily-report` |
| Reviewing a PR for security regressions | `review-pr` / `senior-pr-review` |

This skill is outbound-only and event-driven by an external signal. If the trigger is an inbound message hitting the user's queue, punt to `triage` for classification first; `triage` may then hand off here if the message turns out to be an external advisory worth amplifying.

## Inputs

- Advisory source: URL, vendor bulletin, tweet, or pasted excerpt.
- Affected surface: AI tool, MCP server, model provider, dependency.
- Optional severity hint from user (otherwise infer from advisory text).

## Pipeline

1. Spot and normalize the advisory
   - Extract: vendor, CVE/incident ID if any, attack class, affected versions, exploit prerequisites, public exploit status.
   - Map to internal exposure: do we run the affected tool/MCP/model? Which envs?

2. Resolve destinations and verify IDs
   - Default destinations: `#security` channel, platform-team group DM, `#devops` for awareness reinforcement.
   - Resolve channel/user IDs via `mcp__plugin_slack_slack__slack_search_channels` and `mcp__plugin_slack_slack__slack_search_users`.
   - For every user ID before any send: call `mcp__plugin_slack_slack__slack_read_user_profile` to confirm identity. No fallback. If the profile call fails or returns a mismatch, abort and surface the error — do not guess. (Misdelivery on 2026-04-29 is the reason this gate exists.)

3. Draft summary + mitigation and stage as drafts
   - Summary template: one-line headline, 3-5 bullets (attack class, blast radius, prerequisites, internal exposure, public exploit status), advisory link.
   - Mitigation template: rotation (creds/tokens), sandbox (process isolation, network egress), scanner (Snyk skill scanner, dependency audit), scoped identity (least-privilege role, ephemeral creds), with a recommended action and owner.
   - Stage via `mcp__plugin_slack_slack__slack_send_message_draft` for `#security` and the devops DM. Show drafts to the user for approval before posting.

4. Post and drive the thread
   - On approval, send via `mcp__plugin_slack_slack__slack_send_message` to verified destinations.
   - Cross-link the `#security` post into `#devops` for broader awareness when the advisory is high-impact.
   - Watch the thread via `mcp__plugin_slack_slack__slack_read_thread`; reply with follow-ups, tag owners for mitigation actions, and convert decisions into action items.
   - Use `mcp__plugin_slack_slack__slack_search_public` to surface prior internal mentions of the same vendor/advisory so the thread does not duplicate context.

## Outputs

- Posted summary in `#security` (message permalink).
- Posted summary + mitigation proposal in devops group DM (message permalink).
- Optional cross-post in `#devops`.
- Action items per mitigation lever with named owners.
- Wiki log entry appended to `~/voltage/wiki/log.md` via voltage-scribe with the advisory, destinations, and resolved actions.

## Failure modes

| Failure | Cause | Response |
|---------|-------|----------|
| Wrong user gets DM'd | Skipped profile verification | Hard-stop. Always call `slack_read_user_profile` before send. |
| Duplicate post | Did not search prior mentions | Run `slack_search_public` for vendor + advisory ID first. |
| No-op thread (no replies) | Summary too vague, no asked action | Mitigation must name a specific lever and owner; tag explicitly. |
| Advisory turns out internal/Wiz | Misclassified inbound as outbound | Hand off to `triage`; this skill is external-advisory-only. |
| Mitigation outpaces facts | Speculation beyond advisory text | Quote advisory verbatim for claims; mark inferences explicitly. |

## Token economics

- Advisory text fetched once and quoted in drafts; do not re-fetch per channel.
- Drafts staged before send keep edit cycles cheap (no re-post cleanup).
- Thread monitoring is read-only and pull-based — open thread on demand, do not stream.
- Wiki logging delegated to voltage-scribe; this skill returns the post permalinks and lets the scribe handle persistence.

---
name: triage
description: Run the your-triage-agent triage pipeline — fetch messages from Slack, email, calendar, classify, draft replies, and update the wiki. Use when user says "triage", "check messages", "morning triage", "what do I have", or "briefing".
argument-hint: "[all | slack | email | calendar]"
---

Run the your-triage-agent triage pipeline.

## Input

- `/triage` or `/triage all` — full triage across all channels
- `/triage slack` — Slack only
- `/triage email` — email only
- `/triage calendar` — calendar check only

Default: all channels.

## Execution

1. Spawn the `your-triage-agent` agent with this prompt:

```
Run a triage session for: {channels}

Steps:
1. Delegate to your-triage-fetcher to fetch raw messages from {channels}
2. Read wiki context from ~/your-triage-agent/ (triage patterns, channel priorities, people)
3. Classify each message using the 4-tier system (skip/info_only/meeting_info/action_required), then assign each a routing verdict (auto_digest | team_feed | surface) + confidence per the Routing Contract in ~/your-triage-agent/wiki/patterns/triage.md. Low confidence always routes surface.
4. For action_required: read person's wiki page, draft reply with correct tone
5. Present the briefing. SHADOW MODE: show everything as today with each item tagged [verdict/confidence]; end with the Shadow Routing Summary (per-verdict counts + ask the user to flag any item they'd have wanted surfaced). For each action_required item, emit the fields for a Triage Send Pack: To + relationship, channel, tier; the inbound trigger (one line); what it commits the user to (deadline/promise/nothing); the DRAFT reply verbatim; 1–3 send/edit/skip drivers; outward-facing risk
6. After user processes drafts, delegate to your-triage-scribe to update the wiki, including one line per item appended to ~/your-triage-agent/wiki/routing-shadow.jsonl with user_agreement from the flag-check
```

2. Present the briefing to the user.

3. For each `action_required` item, present it as a **Triage Send Pack** (format below) with `[Send] [Edit] [Skip]`. The pack recommends; your-triage-agent never sends. Sending is the user's explicit Type-1 gate — anything reaching an external channel requires the human yes.

4. After all items are processed, your-triage-agent delegates wiki updates to your-triage-scribe.

## Triage Send Pack

The one-screen artifact for the send / edit / skip decision on an `action_required` item. Mirrors the your-pr-reviewer Merge Decision Pack, adapted to outbound messages. Decision support — it recommends, it never sends.

```
### Triage Send Pack — {person}  ·  {channel}

ACTION:   ✅ SEND   |   ✏️ EDIT FIRST   |   ⏭️ SKIP
WHY:      <≤15 words: why this reply, this tone, now>

To:        {person} ({relationship}) · {channel} · tier: action_required
Trigger:   "<the inbound ask, one line>"
Commits:   {deadline / promise / nothing}

DRAFT (verbatim — sent exactly as shown):
  ┌─
  │ {draft reply, verbatim}
  └─

DECISION DRIVERS  (the 1–3 facts that determine send / edit / skip)
  • {tone matched to person page / prior thread}
  • {commitment or deadline the reply makes}

RISK:      {outward-facing; names / links / numbers checked}   | or: {flag}
IF SEND:   posts to {channel} as you, immediately — not cleanly reversible
IF SKIP:   {what stays open — follow-up needed?}
```

Rules:
- ACTION + a one-line WHY first; the draft shown **verbatim** (never paraphrased — the user must see exactly what will be sent).
- `Commits` surfaces any promise / deadline so it becomes a tracked pending item if sent.
- DECISION DRIVERS ≤ 3; WHY ≤ 15 words. Scannable, not prose.
- The pack RECOMMENDS. It adds no auto-send. Sending stays an explicit human yes (your-triage-agent is not an autonomous decision-maker).

## Shadow Routing (active since 2026-07-17)

Every triaged item gets a routing verdict (auto_digest | team_feed | surface) + confidence alongside its tier. Contract, escalation triggers, graduation rule, and ROI baseline live in `~/your-triage-agent/wiki/patterns/triage.md` → Routing Contract. While in shadow: nothing is hidden, items carry `[verdict/confidence]` tags, verdicts + user agreement land in `~/your-triage-agent/wiki/routing-shadow.jsonl`. A class flips to live routing only per the graduation rule (≥3 sessions, ≥50 items, zero disagreements), and outbound sends stay human-gated forever regardless.

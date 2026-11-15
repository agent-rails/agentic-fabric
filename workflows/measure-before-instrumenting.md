# Measure before instrumenting

## Goal

Spend effort on the lever that moves the cost or delay you actually have, find it in logs you already keep, and drop levers that do not work.

## Steps

1. Once a week, build a report from existing logs only: session transcripts, hook decision logs, the review log. No model calls, no network, aggregates only. Save a dated snapshot, since transcripts may not be kept long.
2. Name bottlenecks with fixed rules (thresholds, shares, rates), not model judgement. Each bottleneck carries one metric and one lever.
3. Keep a lever ledger. When a bottleneck first appears, record its metric as the baseline. On each later run, mark it improved if the metric moved at least 10% in the good direction; after 2 runs without that, mark it dropped and stop acting on it.
4. Add instrumentation only for a gap that blocks a decision you want to make, and write down the decision.
5. Print the limits of the data in every report: what is not covered, what is inferred.

## What enforces it

Not yet enforced; manual. The report and the ledger are planned for the `fabric-metrics` plugin.

## Evidence

Observed, Claude Code sessions on one machine, method: stdlib-only report over local transcripts, no model calls, about one second per month of history (2026-10-11):
- 30 days to 2026-10-11, 13 main sessions, 95 subagent runs, 6,516 API calls: main sessions carried 96% of output tokens and 93% of cache reads; subagents were about 8% of prompt tokens processed. A subagent model router acts on that small share; context size was the larger lever (calls over 600K tokens of context were 24% of calls and 44% of cache reads).
- One lever that did not work: an advisory nudge when context grew past a threshold. Three weekly reports, 2026-10-12 to 2026-11-02: 0 of 18 measured nudges were followed by a drop in context within five calls. By step 3 it qualifies to drop.
- Transcripts repeat one message's usage on every content block. Summing per record overcounted output tokens 2.8 times on one session; count once per message ID.

## Failure modes

- Counts instead of rates. Turn-limit stops fell from 14 to 3 between two weekly reports while subagent runs fell from 36 to 14: the rate moved from 39% to 21%, a smaller change than the count suggests.
- Overlapping windows double-count. Compare non-overlapping weeks.
- A report that crashes on one unexpected log value. One run, 2026-11-09, stopped mid-output on a `null` in a hand-written log; see [narrow-json-error-catch](../patterns/narrow-json-error-catch.md).
- Attributing a change to a lever without a comparison. The ledger says whether the metric moved, not why.
- Tool wait includes time spent on permission prompts; the two cannot be separated from transcripts.

## Adopting it

1. Start with one report over the logs you have, and one table: where tokens and time go.
2. Pick at most three levers, each with a metric, and enter them in the ledger.
3. Rerun weekly. Drop what has not moved after two runs; add instrumentation only for a decision that is blocked without it.

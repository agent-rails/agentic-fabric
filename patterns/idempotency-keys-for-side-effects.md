# Idempotency keys for side-effecting agent tools

Kind: pattern.

## Problem

An approval gate decides whether an action is allowed. It does not stop the same allowed action from running twice when a retry, a resumed session or a re-run command dispatches it again.

## Context

Agent tools that change state outside the conversation: place an order, issue a refund, book a slot, send a message, open a ticket.

## The pattern

- Key each side effect on something stable across a retry: a client-supplied idempotency token, or a hash of task ID, step and arguments.
- Store the outcome under that key before returning it.
- A repeat of the same key is a no-op that returns the stored result.
- Bound runs by wall-clock time as well as turn count; a turn limit does not stop a slow side effect.

## Evidence

Observed: gap analysis of one agent template, 2026-08. Its two money-moving tools had approval thresholds and no idempotency key. No duplicate execution was recorded and the gap was still open at the time of writing. n = 1, a design finding rather than an incident.

## When it does not hold

Naturally idempotent operations (set a value, replace a whole document) need no key. Read-only tools need none.

## Related

- [silent-no-op-safety-configuration](silent-no-op-safety-configuration.md)
- [reviewer-limit-reported-as-clean](reviewer-limit-reported-as-clean.md)

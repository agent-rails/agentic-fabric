# Catching only JSONDecodeError around json.loads

Kind: anti-pattern.

## Problem

A reader meant to skip malformed lines catches `json.JSONDecodeError`. Some malformed input raises a plain `ValueError` instead, and the reader crashes.

## Context

Python readers of logs, JSONL decision records and hand-edited files, where one bad line should be counted and skipped.

## What goes wrong

`JSONDecodeError` is a subclass of `ValueError`, but not every `ValueError` from `json.loads` is a `JSONDecodeError`. An integer literal longer than the interpreter's digit limit (4300 by default) raises plain `ValueError`. Bad UTF-8 raises `UnicodeDecodeError`, also a `ValueError` subclass.

## Do instead

- Catch `ValueError`; it covers all three.
- Count skipped lines and report the count, so skipping is visible.
- Check the type of each decoded field before arithmetic: a field that is `null` in one hand-written row is the same failure one step later.

## Evidence

Observed:
- `python3 -I -c 'import json; json.loads("1" * 5000)'` raises `ValueError: Exceeds the limit (4300 digits) for integer string conversion`, not `JSONDecodeError`. Python 3.14.7, 2026-11-15.
- One log reader, 2026-11-14, had the narrow catch; fixed with a test that failed first. n = 1.
- A weekly metrics report, 2026-11-09, stopped mid-output on a `null` severity count in a hand-written review log (`TypeError`). n = 1.

## When it does not hold

Configuration and other input that must be correct should not be skipped at all: fail with the file, the line and the fix. See [decision 0003](../docs/decisions/0003-settings-not-edits.md).

## Related

- [silent-no-op-safety-configuration](silent-no-op-safety-configuration.md)
- [measure before instrumenting](../workflows/measure-before-instrumenting.md)

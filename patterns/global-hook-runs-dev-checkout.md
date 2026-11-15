# A global hook that runs a development checkout

Kind: anti-pattern.

## Problem

A hook that fires on every tool call or subagent spawn imports its logic from a live development checkout. Whatever is checked out at that moment runs with the hook's authority.

## Context

Hooks that depend on a library you also develop, especially Python hooks that add a working tree to `sys.path` or set `PYTHONPATH`.

## What goes wrong

- Checking out a contributor's branch to review it is enough to execute its code on your next tool call.
- Behaviour changes with `git checkout`, so no two runs are comparable and a bug cannot be pinned to a version.
- Python puts the script's directory on `sys.path` and honours `PYTHON*` variables, so a planted module next to the script or in the environment can shadow the real one.

## Do instead

- Load from a pinned copy at a reviewed commit, kept under `~/.claude/` (or, for a plugin, shipped inside the plugin and read from `${CLAUDE_PLUGIN_ROOT}`). Update the pin on purpose; record the commit and check a tree hash.
- Run hook interpreters isolated: `python3 -I` implies `-E` (ignore `PYTHON*`), `-P` (no script directory on `sys.path`) and `-s` (no user site-packages).
- Detection: grep hook scripts and hook command lines for working-tree paths and for `python3` without `-I`.

## Evidence

- Observed: one routing hook, 2026-11, imported a development checkout on every subagent spawn; found in review and replaced with a pinned copy run under `python3 -I`. n = 1, from the review log.
- Flag semantics: `python3 --help`, Python 3.14.7, 2026-11-15.

## When it does not hold

A hook that only calls installed, versioned binaries has no checkout to run, but still trusts `PATH`. A compromised `PATH` defeats every gate; see the [threat model](../docs/THREAT_MODEL.md) assumptions.

## Related

- [keyword-list-as-security-control](keyword-list-as-security-control.md)
- [hook-fail-closed-without-onfailure](hook-fail-closed-without-onfailure.md)

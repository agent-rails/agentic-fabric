# 0003: Customisation goes through settings, never edits to shipped files

Status: accepted.

## Decision

Anything a user may need to change (a branch prefix, extra protected paths, an unlock window) is a plugin option with a matching key in `~/.config/agentic-fabric/config.json`. Shipped files stay byte-identical to the release.

## Rejected

- Copy the files and replace placeholders. Every adopter then runs a private fork; an update means a merge, and nobody can tell a customisation from a stale copy.
- Rewrite values at install time. A second, transformed copy of each script drifts from the tested one.

## Consequences

Hooks read settings through one small reader, copied into each plugin because a plugin's install directory holds only its own files. Unreadable settings are an error, never a silent default.

## Would change if

Claude Code exposed plugin options to every component, not only hooks and MCP servers.

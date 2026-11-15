# Security policy

These plugins run hooks on an agent's tool calls with your user's permissions. Read a plugin's README ("What runs") before you enable it.

## Reporting a vulnerability

Report privately through GitHub's private vulnerability reporting (Security tab, "Report a vulnerability"). Please include what you found, how to reproduce it, and the impact. Allow reasonable time for a fix before public disclosure.

In scope: a way to get past a gate that its README says it stops; a hook that fails open where it is documented to fail closed; a default that exposes data; the release scan letting private data or a credential into a release.

Out of scope: Claude Code, `gh`, `git` and other tools themselves; and the limits each threat model already lists, such as writes through the Bash tool.

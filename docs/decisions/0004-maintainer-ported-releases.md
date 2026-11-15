# 0004: Releases come from one source; outside changes are ported, not merged

Status: accepted. Revisit when outside pull requests become regular.

## Decision

The maintainer's working copy is the single source. A release is built from an allowlist of files, scanned for private data and credentials, tested, validated, and published as one commit. Pull requests are welcome as proposals; accepted changes are ported into the source and credited in the release commit. The release tool refuses to run when `main` holds a tree it did not produce.

## Rejected

- Merge pull requests on GitHub. The next release would overwrite them, or the two copies would drift.
- Mirror the maintainer's whole configuration. Most of it is personal workflow; publishing it buries what is reusable and widens what could leak.

## Consequences

Contributors wait for a release to see their change. Every published tree is recorded, so a release that does not match its record is refused before it is pushed.

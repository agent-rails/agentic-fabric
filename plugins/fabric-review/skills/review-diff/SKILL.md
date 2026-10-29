---
description: Reviews a diff, patch or pull request for defects. Use when asked to review code changes, a diff, a patch or a PR.
---

Review the diff for defects that would break behavior, security or data integrity. Ignore style, naming and formatting.

For every candidate defect:

1. Locate it: the file and the line number in the new version of the file, taken from the hunk header and the `+` lines.
2. Name the class of defect in one or two words (for example `sql-injection`, `missing-authorization`, `race-condition`, `path-traversal`, `hardcoded-secret`, `timing-attack`, `logic-error`).
3. State the evidence: the concrete input or sequence of events that makes it fail, traced through the code shown in the diff. If you cannot state one, you do not have a finding. Drop it, or report it as a question rather than a defect.
4. Set the severity from the evidence, not from how bad the class sounds. `critical` or `high` only when the failing input is concrete and reachable from the code shown. A defect you could not trace to a failing input is at most `low`.

Do not report a problem that the diff does not introduce or that the shown context already prevents. Check the surrounding context lines before reporting: a check that exists on a neighboring code path is evidence that the new path is missing it.

Report each defect on its own line in the format the request asks for. When the request gives no format, use:

`FINDING: <file>:<line> <class> <severity> - <evidence>`

When you find no defects, say so in the form the request asks for, and do not invent one to have something to report.

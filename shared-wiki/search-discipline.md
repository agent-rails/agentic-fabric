# Search Discipline

Code search ranking rules for any agent that uses Grep/Glob before reasoning.

Source: https://entire.io/blog/improving-agentic-search-in-coding-agents
The big finding: ranking on the FIRST query is where wins live. Speed of
search is <1% of agent wall-clock; result quality dominates. Hit@1 went
26% → 34% and output dropped 6.6KB → 1.6KB by changing ranking, not speed.

## 1. Definition-first

When grepping for a symbol, anchor on its declaration before usages:

- Python:        `^(def|class|async def)\s+<sym>\b`
- TS/JS:         `(export\s+)?(default\s+)?(function|class|const|let|var)\s+<sym>\b|^\s*<sym>\s*[:=]\s*(\(|async)`
- Go:            `^func(\s+\(\w+\s+\*?\w+\))?\s+<sym>\b|^type\s+<sym>\b`
- Rust:          `^(pub\s+)?(fn|struct|enum|trait|impl)\s+<sym>\b`

Cite the definition `path:line` BEFORE any usage in your output. Only fall
back to bare `<sym>` if the anchored pattern returns 0 hits.

## 2. Path priors (demote noise)

Default exclude globs on every Grep unless QUESTIONS demand otherwise:

`!**/node_modules/**`, `!**/dist/**`, `!**/build/**`, `!**/.next/**`,
`!**/vendor/**`, `!**/_worktrees/**`, `!**/*.min.js`,
`!**/*.generated.*`, `!**/coverage/**`

Source > tests > generated > vendor. Surface tests only when:

- QUESTIONS mention behavior / contract / regression, or
- the user explicitly asks for tests, or
- the symbol is not findable in source.

## 3. First-query leverage

The first Grep determines whether the next N calls are exploration or
confirmation. Spend planning time on it:

- Pick the most specific symbol you have. Don't grep `user` — grep the
  function name, the error string, the import path.
- If the symbol is generic, qualify it: `class\s+User\b` not `User`.
- Never start with `.*<sym>.*` — it lies about ranking.

## 4. Task-type priors

| TASK_TYPE        | First query targets                                  | Avoid                       |
|------------------|------------------------------------------------------|-----------------------------|
| implementation   | definition of nearest symbol; existing similar feature | call-graphs, tests        |
| understanding    | call-sites + data flow + type definitions           | unrelated branches          |
| debugging        | error string verbatim, recent diff, stack frame syms | architecture overview       |
| repo-survey      | top-level entry points, package manifests, ownership | leaf utilities              |

If the input envelope provides TASK_TYPE, use the matching prior. If not,
infer from the verb in the task ("add" / "fix" / "explain" / "map").

## 5. Grouped output

Any Grep with >20 hits: group by top-level directory, keep top 3 per group.
Never paste raw Grep output into your final answer — only `path:line` plus a
one-line snippet. Aim for <2KB of search content in any handoff.

## 6. Stop early

If the first query answers the question, stop. Tool budget is a ceiling,
not a target. Speed gains are dwarfed by inference time — the way to be
fast is to need fewer turns, not faster turns.

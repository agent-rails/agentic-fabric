# your-pr-reviewer Wiki — Schema

This document defines the structure, ingestion rules, and page templates for the PR review wiki. your-pr-reviewer is the Principal DevOps Architect's code review agent — it builds institutional knowledge from every PR reviewed and uses that knowledge to give increasingly sharp, context-aware reviews.

## Three-Layer Architecture

```
sources/     Immutable raw inputs. PR diffs, architecture decisions, incident postmortems.
wiki/        LLM-maintained markdown. Updated after every review.
schema.md    This file. Defines structure, templates, and ingestion rules.
```

## Wiki Structure

```
wiki/
  index.md              Navigation hub — auto-generated
  log.md                Review log — what was reviewed, when, what pages were affected

  repos/                One page per repository. Conventions, patterns, common issues, ownership.
    _template.md

  authors/              One page per PR author. Review patterns, common mistakes, growth areas.
    _template.md

  patterns/             Recurring good patterns worth encouraging.
    _template.md

  anti-patterns/        Recurring bad patterns with fixes. The core value of the wiki.
    _template.md

  pending/
    follow-ups.md       Issues flagged in reviews that need verification in future PRs.
    tech-debt.md        Tech debt spotted during reviews, not worth blocking but worth tracking.

  conventions/
    naming.md           Naming conventions observed across repos.
    error-handling.md   Error handling patterns per language/framework.
    testing.md          Testing conventions, coverage expectations.
    security.md         Security patterns, auth flows, input validation.
    api-design.md       API conventions, versioning, contract patterns.
    infra.md            Infrastructure patterns, K8s, Terraform, ArgoCD conventions.
```

## Ingestion Rules

After every PR review:

1. Identify entities: repo, author, patterns (good and bad), conventions violated/followed
2. For each entity:
   - If wiki page exists: update with new observations
   - If no page exists: create from `_template.md`
3. If a new anti-pattern is found: create or update `anti-patterns/{name}.md`
4. If a good pattern is found: create or update `patterns/{name}.md`
5. Update `pending/follow-ups.md` if review flagged items needing future verification
6. Append to `wiki/log.md`
7. Regenerate `wiki/index.md`

### What Gets Ingested

| Source | What to extract |
|---|---|
| PR diff + review | Anti-patterns found, patterns encouraged, conventions violated, author tendencies |
| Architecture decisions | Design patterns to enforce, deprecated patterns to flag |
| Incident postmortems | Root cause patterns to watch for in future reviews |

### What Compounds

Over time, the wiki enables:
- "Author X tends to miss error handling in async code" -> flag proactively
- "Repo Y uses factory pattern for service creation" -> flag when someone doesn't
- "This anti-pattern caused incident Z" -> cite the incident in the review
- "This repo requires integration tests for API changes" -> flag missing tests

## Page Templates

### Repos (`repos/_template.md`)

```markdown
# {Repo Name}

## Overview
- Language:
- Framework:
- Owner team:
- CI/CD:

## Conventions
- Testing:
- Error handling:
- API patterns:
- Naming:

## Common Review Issues
<!-- Recurring problems found in PRs for this repo -->

| Date | PR | Issue | Resolved? |
|------|-----|-------|-----------|

## Architecture Notes
## Dependencies
```

### Authors (`authors/_template.md`)

```markdown
# {Author Name}

## Profile
- Team:
- Primary repos:
- Languages:

## Strengths
<!-- Patterns this author consistently gets right -->

## Growth Areas
<!-- Recurring issues to watch for — not for judgment, for better reviews -->

## Review History

| Date | PR | Repo | Key Findings |
|------|-----|------|-------------|
```

### Patterns (`patterns/_template.md`)

```markdown
# {Pattern Name}

## Description
## When to Use
## Example (from real PR)
## Repos Using This
## Related Anti-patterns
```

### Anti-patterns (`anti-patterns/_template.md`)

```markdown
# {Anti-pattern Name}

## Description
## Why It's Bad
## Fix
## Real Examples

| Date | PR | Repo | How It Manifested |
|------|-----|------|-------------------|

## Related Incidents
## Detection Heuristic
<!-- What to grep/look for in a diff to catch this -->
```

## Review Quality Rules

- Only flag issues that could break production, cause data loss, security vulns, or violate established conventions
- Never flag: style, formatting, minor readability, hypothetical concerns without evidence
- Every flag must cite: what's wrong, why it matters, minimal fix
- When citing a convention, link to the wiki page
- When flagging an anti-pattern, link to the anti-pattern page with incident history

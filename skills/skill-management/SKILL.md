---
name: skill-management
description: Create, update, and manage Claude Code Skill files with proper SKILL.md structure and validation. Use when creating new skills, updating existing skills, troubleshooting skill discovery issues, or when user mentions "skill", "SKILL.md", "add a skill", or "skill not working".
---

## Critical Requirements

> Filename must be `SKILL.md` - uppercase required; lowercase `skill.md` will not be discovered
>
> Restart required - Claude Code loads skills at startup. After creating or modifying skills, restart Claude Code for changes to take effect.

## Skill File Location

- Global: `~/.claude/skills/<name>/SKILL.md`
- Project: `.claude/skills/<name>/SKILL.md`

## Name Requirements

- 1-64 characters
- Lowercase alphanumeric with single hyphen separators
- No leading/trailing hyphens, no consecutive `--`
- Directory name must match `name` in frontmatter
- Regex: `^[a-z0-9]+(-[a-z0-9]+)*$`

## Required Structure

```markdown
---
name: skill-name
description: 1-1024 char description for agent discovery
---

## When to use

[Trigger conditions]

## Pattern

[Steps or commands]

## Why

[Rationale]
```

## Creating a Skill

```bash
# 1. Create directory
mkdir -p ~/.claude/skills/<name>

# 2. Write SKILL.md with frontmatter + content

# 3. Verify
ls ~/.claude/skills/<name>/SKILL.md
```

## Updating a Skill

1. Read existing: `~/.claude/skills/<name>/SKILL.md`
2. Edit with changes
3. Keep frontmatter `name` unchanged (must match directory)

## Description Quality

The `description` is the **only** field the agent sees when deciding whether to load a skill. Treat it as a discovery contract, not a label.

- Max 1024 chars; written in third person
- First sentence: what the skill does
- Second sentence: `Use when [specific triggers, keywords, file types, contexts]`
- Include concrete trigger phrases the user is likely to type

Good: `Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDFs or when user mentions PDFs, forms, or document extraction.`

Bad: `Helps with documents.` — agent has no way to disambiguate from any other doc skill.

## Size Budget

- SKILL.md under 100 lines
- Past that, split into siblings: `REFERENCE.md` (detailed docs), `EXAMPLES.md` (usage), `scripts/` (utilities)
- SKILL.md links one level deep into siblings; do not nest references
- Split when content has distinct domains, or advanced features are rarely needed

## When to Add Scripts

Bundle a script in `scripts/` only when:
- Operation is deterministic (validation, formatting, parsing)
- Same code would be regenerated on every invocation
- Errors need explicit handling that's hard to express in prose

Scripts save tokens and improve reliability vs LLM-generated equivalents. Skip for one-off or context-dependent logic.

## Validation Checklist

- [ ] `SKILL.md` filename is uppercase
- [ ] Frontmatter has `name` and `description`
- [ ] `name` matches directory name
- [ ] `description` is 1-1024 characters with explicit `Use when ...` triggers
- [ ] Name follows regex pattern
- [ ] SKILL.md under 100 lines (split if larger)
- [ ] No time-sensitive info (dates, versions that drift)
- [ ] Concrete examples included

## When to Create vs Update

Create new skill when:
- Workflow used 3+ times
- Multi-step process easy to forget
- Domain knowledge doesn't fit existing skills

Update existing skill when:
- Missing common use case
- Better approach discovered
- API/command changed

## Skills vs Commands

Check for duplicates before creating:
- Before creating a skill, check your existing command bundle for an equivalent
- `x_*` prefix = explicit invocation = command only (not skill)
- Skills auto-trigger; commands require `/command` invocation

Command frontmatter requirements:
```yaml
---
description: Brief description for /help menu
argument-hint: [arg1] [arg2]  # if command accepts arguments
---
```

Dynamic context in commands (use `!` prefix):
```markdown
## Context
- Current branch: !`git branch --show-current`
- Repo: !`gh repo view --json name -q .name`
```

## Troubleshooting

If a skill does not show up:
1. Verify `SKILL.md` is spelled in all caps
2. Check that frontmatter includes `name` and `description`
3. Ensure skill names are unique across all locations
4. Check permissions - skills with `deny` are hidden from agents
5. Restart Claude Code - skills are loaded at startup only

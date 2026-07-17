---
name: session-retrospective
description: End-of-session retrospective to capture learnings, update skills, and improve workflows. Use when completing complex tasks, hitting unexpected challenges, discovering better approaches, or before ending significant sessions (30+ min). Trigger phrases include "retrospective", "what did we learn", "session review", "capture learnings".
---

# Session Retrospective

Reflect on completed work to capture learnings and improve future sessions.

## When to Use

- After completing a complex task with unexpected challenges
- When you discovered a better approach mid-session
- After hitting roadblocks requiring workarounds
- When a skill or workflow was missing/incomplete
- Before ending any significant session (30+ min)
- When user asks for retrospective, learnings, or session review

## When NOT to Use

- Quick single-task sessions (<15 min)
- Tasks completed without friction
- When learnings are already documented
- Pure research/exploration sessions

## Auto-Learn Integration

Before starting the retrospective, check the user's auto-learn preferences:

```bash
your-cli skills config view
```

This returns JSON with:
```json
{
  "disabled": [],
  "autoLearn": {
    "enabled": true,
    "updateExisting": true,
    "createNew": true,
    "targetDir": "private"
  }
}
```

Based on config:
- `autoLearn.enabled=false` → Only suggest skill updates, don't create/modify files
- `autoLearn.createNew=true` → Can create new skills for new workflows
- `autoLearn.updateExisting=true` → Can update existing skills with improvements

## Retrospective Framework

### 1. Identify Friction Points

Ask yourself:
- What took longer than expected? Why?
- Where did I make multiple attempts?
- What information was missing or hard to find?
- Which tools/commands didn't work as expected?

### 2. Categorize & Act

| Category | Action | Where |
|----------|--------|-------|
| Skill gap | Create/update skill | `~/.claude/skills/` |
| Tool quirk | Document in skill | Relevant skill file |
| Codebase knowledge | Add to CLAUDE.md | Project `CLAUDE.md` |
| Process improvement | Update workflow | AGENTS.md or skill |
| External dependency | Document workaround | Skill + upstream issue |

### 3. Capture Pattern

For each friction point:

```markdown
## [Brief title]

Problem: What was harder than expected
Root Cause: Why (missing docs, API quirk, wrong assumption)
Solution: What actually worked
Prevention: How to avoid next time
```

### 4. Apply Skill Updates (Auto-Learn)

For each friction point categorized as "Skill gap":

If creating a new skill (when `autoLearn.createNew=true`):

1. Determine skill name (lowercase, hyphenated, 1-64 chars)
2. Create directory: `~/.claude/skills/<name>/`
3. Write SKILL.md with required structure:

```markdown
---
name: <skill-name>
description: <1-1024 char description>
---

## When to use

[Trigger conditions - when should this skill be invoked]

## Pattern

[Steps, commands, or workflow]

## Why

[Rationale - why this approach works]
```

If updating an existing skill (when `autoLearn.updateExisting=true`):

1. Find the skill: `your-cli skills list -s` to see sources
2. Read and edit the SKILL.md file at `~/.claude/skills/<name>/SKILL.md`
3. Add new section or update existing content
4. Note: If you modify a bundled skill, `your-cli sync` will detect the conflict and prompt for resolution

Important: Always inform the user what changes were made.

## Skill Updates (Manual)

Load `skill-management` skill for detailed instructions on creating and updating skills.

## CLAUDE.md Updates

Add to CLAUDE.md when:
- Project-specific (not general workflow)
- Affects how code should be written
- Documents architectural decisions
- Recurring pattern in this codebase

Format: `- Topic: Key point; detail; example if needed.`

## Commit Decision

| Relevance | Action |
|-----------|--------|
| Related to PR's feature/fix | Same PR |
| General workflow learning | Separate PR |
| Skill updates | Update skill files directly |

## Retrospective Checklist

Before ending session:

- [ ] Check auto-learn config: `your-cli skills config view`
- [ ] Identify 1-3 friction points from the session
- [ ] For each friction point:
  - [ ] Determine category (skill/tool/codebase/process)
  - [ ] Document the solution that worked
  - [ ] If skill gap and auto-learn enabled:
    - [ ] Create new skill OR update existing (based on config)
    - [ ] Verify skill created: `your-cli skills list -s`
  - [ ] Update AGENTS.md if project-specific
- [ ] Brief summary to user of what was captured
- [ ] Remind user to restart Claude Code if skills were modified

## Example Retrospective with Auto-Learn

### Session: CI Investigation with Hidden Failures

Friction Point: CI hook output looked successful but was actually failing

Root Cause: Test coverage table appeared first, actual failure buried at end

Solution: Check exit code explicitly, scroll to end of output

Auto-Learn Actions (config: enabled=true, createNew=true):

1. Checked existing skills: `ci-investigation` exists but missing this case
2. Edited `~/.claude/skills/ci-investigation/SKILL.md`
3. Added new section:

```markdown
## Gotcha: Hidden Test Failures

When a commit hook or similar runs tests with coverage:
- Coverage table appears first (looks successful)
- Actual failures may be at the END of output
- Always check exit code: `command; echo "Exit: $?"`
- Scroll to bottom for "FAIL" or error summary
```

4. Informed user: "Updated ci-investigation skill with hidden failure gotcha"

---

## Quick Prompt

End sessions with:
> "Let's do a quick retrospective - what friction points did we hit and should we update any skills?"

For detailed examples, see [examples/retrospective-examples.md](examples/retrospective-examples.md).

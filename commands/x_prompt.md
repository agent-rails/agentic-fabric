---
description: Display guidelines for writing effective prompts and rules with maximum brevity
---

# Prompt Guidelines

Guidelines for crafting prompts, rules, and instructions with maximum brevity and clarity.

### Usage
```
/x_prompt
```

### Guidelines

- Core principle: Maximum brevity
  - Every word must earn its place
  - Delete filler
  - Compress ruthlessly
  - Shortest accurate term
  - No redundancy

- Rule-crafting scope
  - Define audience upfront
  - Specify execution context
  - Repo-relevant only
  - No speculation

- Form and enforceability
  - Imperative testable statements
  - MUST/SHOULD/MAY only
  - One behavior per bullet
  - Measurable outcomes

- Safety and security
  - No hardcoded secrets
  - UTC timestamps only
  - Validate all inputs
  - Least privilege
  - Parameterized queries

- Execution guarantees
  - List preconditions
  - Define postconditions
  - Specify failure handling
  - Set timeout values

- Clarity and readability
  - Flat structure
  - Functions = verbs
  - Variables = nouns
  - Extract helpers
  - Guard clauses

- Testing standard
  - Fast deterministic tests
  - Test alongside code
  - Mock external deps

- Template for new rules
  - Title: single behavior
  - Context: where/when
  - Rule: MUST action WHEN condition
  - Validation: how to test
  - Exceptions: minimal list

- Formatting structure
  - Bullets for headers
  - Two-space indents
  - No # or ## headers
  - Max 3 levels deep
  - Group related items
  - Use <section>...</section> tags
  - Section tags for major blocks
  - Follow Anthropic conventions

- Guidelines
  - No **bold** or *italics*
  - Maximum brevity
  - One idea per line
  - Fragments not sentences
  - 3-7 words per bullet ideal
  - Omit articles (a/an/the)
  - Use abbreviations where clear
  - Do not use # headings use bullets and sub bullets instead

- Brevity examples
  - Bad: "The system must validate all user inputs"
  - Good: "Validate inputs"
  - Bad: "Use environment variables for configuration"
  - Good: "Use env vars"
  - Bad: "Functions should be named with verbs"
  - Good: "Functions = verbs"

- Section tag usage
  - When: multiple components
  - When: complex prompts
  - When: hierarchical content
  - Separate context/instructions/examples
  - Maintain clear boundaries
  - Prevent misinterpretation
  - Common tags: context, instructions, examples, task, constraints
  - Nest for hierarchy: <outer><inner></inner></outer>
  - Skip for simple single-purpose prompts
  - Example:
    <context>
    Background info here
    </context>
    <instructions>
    - Do X
    - Avoid Y
    </instructions>
    <examples>
    Input: foo
    Output: bar
    </examples>

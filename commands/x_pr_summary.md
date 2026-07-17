---
description: Generate PR summary with diagrams and conventional commit title suggestion
---

# PR Summary

## Context
- Current branch: !`git branch --show-current`
- Last commit: !`git log -1 --pretty=%B 2>/dev/null | head -1`
- Repo: !`gh repo view --json name -q .name 2>/dev/null || basename $(pwd)`
- Changed files count: !`git diff master...HEAD --name-only 2>/dev/null | wc -l`

Generate a comprehensive PR summary by analyzing all changes in the current branch compared to master.

## Instructions

1. **Gather Git Information**:
   - Get the last commit message using `git log -1 --pretty=%B`
   - Get the repository name from the remote URL
   - Get the current branch name

2. **Analyze Changes**:
   - First, get the list of all changed files (excluding lock files and other unwanted files) using bash:
     ```bash
     git diff master...HEAD --name-status | grep -v -E '\.(lock|min\.js|min\.css|map|png|jpg|jpeg|gif|ico|svg|pdf|pyc|log)$|lock\.yaml$|lock\.json$|__pycache__|\.cache/|dist/|build/|\.next/'
     ```
   - Then, **READ ALL changed files** that pass the filter above using the read_file tool
   - Files to exclude:
     - Lock files: `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `poetry.lock`, `Pipfile.lock`, `composer.lock`, `uv.lock`
     - Generated files: `*.min.js`, `*.min.css`, `*.map`, `dist/*`, `build/*`, `.next/*`
     - Binary files and large assets: `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.ico`, `*.svg`, `*.pdf`
     - Cache/temp files: `*.pyc`, `__pycache__/*`, `.cache/*`, `*.log`
   - For each non-excluded file, use the read_file tool to examine its content and understand the changes
   - To see the actual diff for a specific file (ensuring it's not a lock file), use:
     ```bash
     # Only diff if the file is not a lock file
     git diff master...HEAD -- path/to/file
     ```

3. **Determine Complexity**:
   Based on the changes analyzed, categorize the PR complexity:
   - **Tiny Change**: Single-line changes, config updates, version bumps
   - **Simple Change**: Small feature additions, bug fixes affecting 1-3 files
   - **Complex Change**: Major refactoring, new features, changes affecting many files or core functionality

4. **Generate PR Summary**:
   Format your response exactly as follows:

   ```
   [Provide a concise paragraph summary of the changes here. Be brief and keep it as concise as possible. At most this should be 5 sentences. However if the change has multiple separate parts then each part should be summarized in their own paragraph.]

   <details>
   <summary>[Brief description of the diagram] Diagram</summary>

   ```mermaid
   [Simple mermaid diagram visually summarizing the changes.]
   [Avoid using "[" and "]" in labels.]
   [Wrap forward slashes in quotes, e.g., A[Flask App] --> B["/execute"]]
   ```
   [Up to 3 sentence summary explaining the diagram.]
   </details>

   <details>
   <summary>🚨Suggested PR title according to github.com/your-org/conventional-commit-spec🚨</summary>

   [Provide a suggestion for the PR title here that is concise and follows the PR title conventions.]
   </details>
   ```

## PR Title Conventions

Use these conventions when suggesting PR titles:

| Type     | Description                   | Example                                                 |
| -------- | ----------------------------- | ------------------------------------------------------- |
| fix      | For bug patches               | fix: handle rate limit errors from upstream API        |
| feat     | For new features              | feat: add bulk export for reports              |
| refactor | For code restructuring        | refactor: extract CopyField component                   |
| style    | For code style changes        | style: use ternary instead of let reassignment          |
| perf     | For performance improvements  | perf: cache hot config reads at startup       |
| security | For security hardening        | security: harden JSON validation for inbound messages     |
| test     | For tests addition/deletion   | test: add pagination edge case regression test      |
| chore    | For build/dev tooling changes | chore: bump eslint 8.3.0 to 8.3.1                       |
| docs     | For documentation updates     | docs: add long-term platform vision documentation |
| revert   | For revert commits            | revert: enable experimental settings panel      |

Always use `({repo_name})` as the scope where {repo_name} is the repository name.

## Important Guidelines

1. **For Tiny Changes**: Provide only a 1-line summary without any diagrams
2. **For Simple Changes**: Provide a concise paragraph summary without detailed diagrams
3. **For Complex Changes**: Include mermaid diagrams to visually summarize the changes
4. Only include diagrams if they add clarity - they should not be more complex than the code itself
5. Do not add meta-commentary like "Note: No diagram included..."
6. Only suggest a new PR title if the current one doesn't follow conventions
7. Focus on what changed and why, not implementation details

## Execution Steps

1. First, check the current branch and last commit message:
   ```bash
   git branch --show-current
   git log -1 --pretty=%B
   ```
2. Get a filtered list of all changed files (excluding lock files and other unwanted files):
   ```bash
   git diff master...HEAD --name-status | grep -v -E '\.(lock|min\.js|min\.css|map|png|jpg|jpeg|gif|ico|svg|pdf|pyc|log)$|lock\.yaml$|lock\.json$|__pycache__|\.cache/|dist/|build/|\.next/'
   ```
3. **READ EVERY changed file** (except excluded types) using the read_file tool to understand the full context of changes
4. For specific file diffs when needed:
   ```bash
   git diff master...HEAD -- path/to/specific/file
   ```
5. Categorize the complexity based on the number of files changed and the nature of changes
6. Generate the appropriate summary based on complexity
7. Include diagram only if changes are complex
8. Suggest PR title only if current title doesn't follow conventions
9. Copy the generated summary to the clipboard using:
   ```bash
   echo "[Your generated PR summary]" | pbcopy
   ```
   Or provide instructions to the user: "The PR summary has been copied to your clipboard."

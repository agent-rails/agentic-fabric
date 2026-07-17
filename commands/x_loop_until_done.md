---
description: Append quality checklist todos for production-ready code verification
---

# Loop Until Done

## Context
- Current branch: !`git branch --show-current`
- Uncommitted changes: !`git status --short 2>/dev/null | wc -l`

### Instructions
Add these items as your last to do items (IMPORTANT USE THE EXACT WORDING BELOW):
- Manual Testing: Diff all changes from this branch with master. If your changes involve frontend leverage playwright mcp and test the flow. If backend then spin up the backend and manually test the apis. If there are issues iterate and solve them. We want to ensure our code is production ready and manual testing is important.
- Review all changes in branch compared with master. Remove unneeded comments. Fix any code smells. Do not skip tests or cheat on tests.
- Check Core Quality: Diff all changes from this branch with master. Verify you didn't cheat/bypass type checking, testing, or hooks; didn't lower code standards; didn't skip/delete tests; didn't modify code just to pass tests. If any issues found, fix them.
- Check Architecture: Diff all changes from this branch with master. Verify no hardcoded values that should be configurable; no copy-pasted code; no pattern violations; no circular dependencies. If any issues found, fix them.
- Check Frontend Design: Diff all changes from this branch with master. If you make frontend changes check that you are making changes consistent with the design system that is in place. Check for reusable components and global variables.
- Check Error Handling: Diff all changes from this branch with master. Verify proper error handling (no generic try/catch); edge cases covered; no unjustified @ts-ignore/type:ignore; no suppressed linter warnings. If any issues found, fix them.
- Check Documentation: Diff all changes from this branch with master. Ensure docs are updated; no uncommitted TODOs/FIXMEs; no debug code/console.logs; clear variable names. If any issues found, fix them.
- Check Security & Performance: Diff all changes from this branch with master. Verify no bypassed security/validation; no potential vulnerabilities; document any performance trade-offs. If any issues found, fix them.
- Check Testing: Diff all changes from this branch with master. Verify no skipped tests; maintained coverage; strict assertions; no increased timeouts for flaky tests. If any issues found, fix them.
- if cc::commit-hook is defined at the root level package.json run this and iterate until all of these pass. If not run all available tests (unit, integration, e2e) and typescript checking/eslint checking on all changes to verify everything is in a passing state for CI. IF they aren't iterate until fixed.
- Create PR if it doesn't exist for branch -> iterate -> find issues commit -> push -> check ci repeat until all tests all pass

### Reminder
- Leverage to dos and make small atomic commits as you go
- There should be more than the above 11 todo items added. This includes your specific tasks and the ones you should append  - DO NOT compress or combine todos together. Each distinct task should be its own todo item.

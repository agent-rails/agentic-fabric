---
name: parallel-fetch
description: Pattern for parallel subagent delegation when fetching 3+ independent data sources. Use when gathering CI logs, API responses, file contents, or search results in parallel. Trigger phrases include "fetch multiple", "gather data", "parallel fetch", "multiple sources".
---

## When to Use

When you need to fetch or analyze 3+ independent pieces of information (CI logs, API responses, file contents, search results).

## Pattern

Spawn a `general` agent:
```
"Gather and analyze these independent items: [list items]. 
Return structured summary of findings."
```

## Why

- Sequential bash calls for independent queries waste time
- Subagent can parallelize internally
- Reduces context pollution from verbose outputs

## When NOT to Use

- Fewer than 3 data sources (overhead not worth it)
- Quick single commands (<2 sec execution)
- Sequential/dependent data (B needs A's output)
- When you need raw output in main context

---
max_turns: 6
allowed_tools: [Skill, Read]
tags: [seeded]
---

Review this diff. Report each defect on its own line as `FINDING: <file>:<line> <class> <severity> - <evidence>`, where <line> is the line number in the new version of the file. If you find no defects, reply exactly `NO DEFECTS`.

```diff
--- a/authz/levels.py
+++ b/authz/levels.py
@@ -5,4 +5,4 @@
 # A user may approve a payout only if their approval level is at least the payout tier.
 # Tier 3 payouts require approval level 3 or higher.
 def can_approve(user_level: int, payout_tier: int) -> bool:
-    return user_level >= payout_tier
+    return user_level > payout_tier
```

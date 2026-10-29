---
max_turns: 6
allowed_tools: [Skill, Read]
tags: [clean]
---

Review this diff. Report each defect on its own line as `FINDING: <file>:<line> <class> <severity> - <evidence>`, where <line> is the line number in the new version of the file. If you find no defects, reply exactly `NO DEFECTS`.

```diff
--- a/pricing/discount.py
+++ b/pricing/discount.py
@@ -9,3 +9,3 @@
 def order_total(items, discount_rate: float) -> float:
-    total = sum(i.price * i.qty for i in items)
-    return round(total * (1 - discount_rate), 2)
+    subtotal = sum(item.price * item.qty for item in items)
+    return round(subtotal * (1 - discount_rate), 2)
```

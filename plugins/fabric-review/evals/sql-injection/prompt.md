---
max_turns: 6
allowed_tools: [Skill, Read]
tags: [seeded]
---

Review this diff. Report each defect on its own line as `FINDING: <file>:<line> <class> <severity> - <evidence>`, where <line> is the line number in the new version of the file. If you find no defects, reply exactly `NO DEFECTS`.

```diff
--- a/src/orders/repo.py
+++ b/src/orders/repo.py
@@ -18,6 +18,10 @@
 from typing import List
 
 def list_orders(conn, customer_id: int) -> List[dict]:
     cur = conn.execute("SELECT id, total FROM orders WHERE customer_id = ?", (customer_id,))
     return [dict(r) for r in cur.fetchall()]
 
+def search_orders(conn, status: str) -> List[dict]:
+    query = f"SELECT id, total FROM orders WHERE status = '{status}'"
+    cur = conn.execute(query)
+    return [dict(r) for r in cur.fetchall()]
```

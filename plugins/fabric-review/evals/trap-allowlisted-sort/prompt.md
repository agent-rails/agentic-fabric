---
max_turns: 6
allowed_tools: [Skill, Read]
tags: [trap]
---

Review this diff. Report each defect on its own line as `FINDING: <file>:<line> <class> <severity> - <evidence>`, where <line> is the line number in the new version of the file. If you find no defects, reply exactly `NO DEFECTS`.

```diff
--- a/reports/query.py
+++ b/reports/query.py
@@ -20,2 +20,6 @@
 SORTABLE = {"created": "created_at", "total": "total_cents", "status": "status"}
 
+def list_reports(conn, owner_id: int, sort: str):
+    column = SORTABLE[sort]
+    query = f"SELECT id, total_cents FROM reports WHERE owner_id = ? ORDER BY {column}"
+    return conn.execute(query, (owner_id,)).fetchall()
```

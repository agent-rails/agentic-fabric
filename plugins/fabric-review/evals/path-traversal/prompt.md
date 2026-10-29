---
max_turns: 6
allowed_tools: [Skill, Read]
tags: [seeded]
---

Review this diff. Report each defect on its own line as `FINDING: <file>:<line> <class> <severity> - <evidence>`, where <line> is the line number in the new version of the file. If you find no defects, reply exactly `NO DEFECTS`.

```diff
--- a/files/download.py
+++ b/files/download.py
@@ -12,2 +12,7 @@
 BASE_DIR = "/srv/uploads"
 
+@app.route("/files/<path:name>")
+@login_required
+def download(name):
+    full_path = os.path.join(BASE_DIR, name)
+    return send_file(full_path)
```

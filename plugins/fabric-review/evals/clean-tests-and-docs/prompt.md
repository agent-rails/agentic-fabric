---
max_turns: 6
allowed_tools: [Skill, Read]
tags: [clean]
---

Review this diff. Report each defect on its own line as `FINDING: <file>:<line> <class> <severity> - <evidence>`, where <line> is the line number in the new version of the file. If you find no defects, reply exactly `NO DEFECTS`.

```diff
--- a/tests/test_slugify.py
+++ b/tests/test_slugify.py
@@ -1,2 +1,7 @@
 from textutil import slugify
 
+def test_slugify_collapses_whitespace():
+    assert slugify("a   b") == "a-b"
+
+def test_slugify_lowercases():
+    assert slugify("Hello World") == "hello-world"
```

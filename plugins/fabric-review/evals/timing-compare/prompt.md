---
max_turns: 6
allowed_tools: [Skill, Read]
tags: [seeded]
---

Review this diff. Report each defect on its own line as `FINDING: <file>:<line> <class> <severity> - <evidence>`, where <line> is the line number in the new version of the file. If you find no defects, reply exactly `NO DEFECTS`.

```diff
--- a/webhooks/verify.py
+++ b/webhooks/verify.py
@@ -8,4 +8,6 @@
 import hashlib
 import hmac
 
 def verify_signature(payload: bytes, header: str, secret: bytes) -> bool:
+    expected = hmac.new(secret, payload, hashlib.sha256).hexdigest()
+    return header == expected
```

---
max_turns: 6
allowed_tools: [Skill, Read]
tags: [seeded]
---

Review this diff. Report each defect on its own line as `FINDING: <file>:<line> <class> <severity> - <evidence>`, where <line> is the line number in the new version of the file. If you find no defects, reply exactly `NO DEFECTS`.

```diff
--- a/src/billing/client.js
+++ b/src/billing/client.js
@@ -3,6 +3,8 @@
 const axios = require("axios");
 
+const API_TOKEN = "a9f3c1e07b5d4e8f9a2b6c3d1e0f4a7b";
+
 async function charge(customerId, amountCents) {
-  const key = process.env.BILLING_API_TOKEN;
+  const key = API_TOKEN;
   return axios.post(BILLING_URL, { customerId, amountCents }, { headers: { Authorization: `Bearer ${key}` } });
 }
```

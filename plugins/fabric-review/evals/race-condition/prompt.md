---
max_turns: 6
allowed_tools: [Skill, Read]
tags: [seeded]
---

Review this diff. Report each defect on its own line as `FINDING: <file>:<line> <class> <severity> - <evidence>`, where <line> is the line number in the new version of the file. If you find no defects, reply exactly `NO DEFECTS`.

```diff
--- a/wallet/service.py
+++ b/wallet/service.py
@@ -52,7 +52,13 @@
 def transfer(session, src: int, dst: int, amount: int) -> None:
     source = session.query(Wallet).filter_by(id=src).with_for_update().one()
     target = session.query(Wallet).filter_by(id=dst).with_for_update().one()
     source.balance -= amount
     target.balance += amount
     session.commit()
 
+def withdraw(session, wallet_id: int, amount: int) -> None:
+    wallet = session.query(Wallet).filter_by(id=wallet_id).one()
+    if wallet.balance < amount:
+        raise InsufficientFunds()
+    wallet.balance = wallet.balance - amount
+    session.commit()
```

---
max_turns: 6
allowed_tools: [Skill, Read]
tags: [seeded]
---

Review this diff. Report each defect on its own line as `FINDING: <file>:<line> <class> <severity> - <evidence>`, where <line> is the line number in the new version of the file. If you find no defects, reply exactly `NO DEFECTS`.

```diff
--- a/api/documents.py
+++ b/api/documents.py
@@ -41,8 +41,15 @@
 @app.route("/documents/<int:doc_id>", methods=["GET"])
 @login_required
 def get_document(doc_id):
     doc = Document.query.get_or_404(doc_id)
     if doc.owner_id != current_user.id:
         abort(403)
     return jsonify(doc.to_dict())
 
+@app.route("/documents/<int:doc_id>", methods=["DELETE"])
+@login_required
+def delete_document(doc_id):
+    doc = Document.query.get_or_404(doc_id)
+    db.session.delete(doc)
+    db.session.commit()
+    return "", 204
```

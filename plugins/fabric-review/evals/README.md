# Seeded-defect corpus

Each `seeded` case is one diff with one planted defect; each `clean` case has none. A seeded run is scored by two graders. `detects` passes when a `FINDING:` line names the file and a class keyword on the same line, anchored at a word boundary so `traced` cannot match `race`, at any line. `located` passes when that line number is also within one of the planted line, so the two separate finding the defect from locating it. This measures recall only: a seeded diff can contain real defects that were not planted, so extra findings on a seeded case are not scored. Precision is measured two ways. `clean` cases have no defect at all: any `FINDING:` line is a false positive and `NO DEFECTS` is required. `trap` cases look like a classic defect but are safe in the context shown, and real code can still have other minor issues, so they are scored only on whether the specific false claim (the trap's class) is raised.

| case | file | seeded new-file lines | accepted lines |
|---|---|---|---|
| sql-injection | `src/orders/repo.py` | 25 | 24, 25, 26 |
| missing-authorization | `api/documents.py` | 52 | 51, 52, 53 |
| race-condition | `wallet/service.py` | 60 | 59, 60, 61, 62, 63, 64 |
| hardcoded-secret | `src/billing/client.js` | 5, 8 | 4, 5, 6, 7, 8, 9 |
| path-traversal | `files/download.py` | 17, 18 | 16, 17, 18, 19 |
| timing-compare | `webhooks/verify.py` | 13 | 12, 13, 14 |
| off-by-one-permission | `authz/levels.py` | 8 | 7, 8, 9 |
| clean-refactor | `pricing/discount.py` | none | none |
| clean-tests-and-docs | `tests/test_slugify.py` | none | none |
| trap-allowlisted-sort | `reports/query.py` | none | none |
| trap-constant-time-compare | `webhooks/verify.py` | none | none |

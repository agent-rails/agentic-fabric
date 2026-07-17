---
paths: "**/*.py"
---

 - Environment
   - Python >= 3.13.7; use local virtual env `.venv` (uv/venv) and activate before running tools

 - Formatting & Linting (Ruff)
   - Run `ruff check` and `ruff format` locally and in pre-commit; CI enforces the same
   - Style: line length 120, double quotes, spaces for indentation
   - Underscore-prefix for intentionally unused variables is allowed

 - Types
   - Pyright and mypy are both used; keep exported/public functions fully annotated
   - Enable strict-ish checks; prefer precise types over `Any`; use `typing_extensions` when needed

 - Structure & Readability
   - Prefer guard clauses and early returns; avoid deep nesting
   - Keep functions small and single-purpose; extract helpers instead of adding flags
   - Name functions as verbs and variables as clear nouns; avoid abbreviations

 - Error Handling
   - No bare `except`; catch specific exceptions; include actionable context in messages
   - Avoid swallowing errors; either handle or re-raise with `raise ... from err` when adding context

 - Time & Locale
   - All timestamps must be UTC; use timezone-aware `datetime` (`datetime.now(timezone.utc)`)
   - Convert external/local times to UTC at boundaries; compare/store only in UTC

 - IO, HTTP, and Concurrency
   - Use async-first patterns where appropriate; prefer `asyncio.gather` for independent tasks
   - Propagate cancellations; never ignore task exceptions; set reasonable timeouts

 - Validation & Security
   - Validate all external inputs with Pydantic v2; never trust request payloads
   - Never hardcode secrets; use env vars (`python-dotenv`) and least-privilege IAM
   - Use parameterized queries with SQLAlchemy; sanitize/escape user-controlled strings

 - Tests
   - Write pytest tests (incl. async) alongside code; aim for fast, deterministic tests
   - Prefer fixtures over global state; avoid network/filesystem unless explicitly needed

 - Performance
   - Measure before optimizing; batch DB and network calls when safe; avoid N+1 patterns
   - Cache hot reads with explicit TTLs; validate cache invalidation paths
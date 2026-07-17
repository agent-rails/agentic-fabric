# Error Handling Conventions

## TypeScript
- Custom Error classes mapped by HTTP status
- Early return for auth and validation
- Non-critical failures: logged, not thrown
- Never swallow errors silently

## Python
- No bare `except`
- Catch specific exceptions
- Include actionable context in messages
- `raise ... from err` when adding context

## General
- Fail fast — no silent fallbacks
- No fallback logic "in case something doesn't work" — we want to find bugs early
- Validate at system boundaries (user input, external APIs)
- Trust internal code and framework guarantees

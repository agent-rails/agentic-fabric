# API Design Conventions

## TypeScript (Next.js App Router)
- `withValidation` helper for route handlers
- Zod body schemas
- 80% business logic / 20% boilerplate in route files
- Early return for auth failures

## General
- Guard clauses for validation
- Explicit return types on exported functions
- `import type` for type-only imports
- Retries use exponential back-off (except validation/JSON parse errors)

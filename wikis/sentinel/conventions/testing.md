# Testing Conventions

## General
- Tests co-located with source code
- Fast, deterministic — no network/filesystem unless explicitly needed
- Fixtures over global state
- Integration tests hit real database, not mocks (mocks masked a broken migration previously)

## TypeScript
- Vitest with `vitest.config.mts`
- `test.concurrent` for independent cases
- AI integration tests: `.test.ai.ts` (skipped on standard CI)

## Python
- pytest (including async)
- Fixture-driven
- Run suite and address failures immediately

## PR Review Checks
- New code must include tests
- API changes require integration tests
- Edge cases explicitly tested

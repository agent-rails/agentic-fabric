---
paths: "**/*.{ts,tsx,js,jsx}"
---

 - Project Structure
   - Feature-based directories → Co-locates React, API, tests, utils (easier deletion/portability)
   - Minimal index.ts re-exports → Avoids circular deps; explicit > implicit
   - Tests next to source → Encourages maintenance, greppable

 - Naming
   - Files & Dirs: kebab-case (`transaction-signer.ts`)
   - Components: kebab-case (`user-avatar.tsx`)
   - Constants: SCREAMING_SNAKE_CASE (`MAX_TOKENS_IN_ESCROW`)
   - Booleans: `is`, `has`, `should*` (`isVerified`)
   - Event Handlers: `handle*` (`handleClick`)
   - Rationale: Consistent casing = low cognitive load & zero Git rename churn.

 - TypeScript
   - Interfaces for extensible object shapes, types for unions & aliases
   - `import type` → Eliminates accidental value import, smaller bundles
   - Explicit return types on exported functions → Guards against implicit `any`
   - Generics for reusable helpers → e.g. `promptJson<T>()` pattern

```typescript
export interface User {
  id: string;
  username: string;
}

export type ActivityType = 'SIGNUP' | 'SEND' | 'AIRDROP';
```

 - Imports
   - Order with blank lines between groups:
     - Node built-ins
     - External packages
     - Internal aliases `@/*`
     - Relative imports

```typescript
import { readFileSync } from 'fs';

import invariant from 'tiny-invariant';
import { jwtVerify } from 'jose';

import { WEB_APP_URL } from '@/lib/constants';

import { buildRedirectURL } from './utils';
```
   - Reason: Git diffs remain stable; merge conflicts trivial to solve.

 - Constants & Environment
   - SCREAMING_SNAKE_CASE for true constants → Visual cue they never change
   - Validate required env vars once at start-up → Fail fast, predictable runtime
   - Don't wrap constants in objects → Enables tree-shaking

```typescript
export const TRUST_SCORE_THRESHOLD = 1; // magic numbers deserve a name

export const API_URL =
  process.env.NODE_ENV === 'production'
    ? 'https://api.example.com'
    : 'https://localhost:3001';
```

 - Error Handling
   - Custom Error classes mapped by HTTP status → single source of truth
   - Early return for auth & validation issues → reduces nesting
   - Non-critical failures are logged, not thrown → user experience unaffected

```typescript
class ForbiddenError extends Error {
  constructor() {
    super('Forbidden');
    this.name = 'ForbiddenError';
  }
}

const Errors: Record<number, ErrorConstructor> = {
  403: ForbiddenError,
  404: NotFoundError,
};
```

 - API Design
   - Next.js App Router patterns with `withValidation` helper:

```typescript
export const POST = withValidation(
  async (_req, { body }) => {
    const user = await getCurrentUser(_req);
    if (!user) return new Response('Unauthorized', { status: 401 });

    const { toUsername, amount } = body;
    // …business logic…
    return Response.json({ success: true });
  },
  { body: transferBodySchema },
);
```
   - Rationale: Keeps route files 80% business logic / 20% boilerplate.

 - React & UI Patterns
   - Hooks return `{ data, isLoading, error }` → Uniform consumer ergonomics
   - Contexts expose minimal surface → Prevents accidental re-renders
   - Memoize expensive selectors → Performance on large lists

```typescript
function useUser(username: string) {
  const { data, error } = useApi<User>(`/users/${username}`);
  return { user: data, isLoading: !data && !error, error };
}
```

 - Async & Concurrency
   - Prefer `async/await` → clearer stack traces
   - Use `Promise.all` for independent calls but never swallow rejections
   - Retries use exponential back-off unless error is validation/JSON parse

```typescript
await pRetry(() => fetchExternal(id), { retries: 3, factor: 2 });
```

 - Functions & Methods
   - Arrow functions for inline callbacks
   - Named functions for top-level exports → debuggable stack traces
   - Guard clauses → fail fast, flatten code

```typescript
export async function send({ from, to, amount }: SendParams) {
  if (amount <= 0) throw new Error('Amount must be positive');
  // happy path below
}
```

 - Database (Prisma)
   - PascalCase model names; camelCase fields → Mirrors TypeScript defaults
   - Explicit relation names + `onDelete` → Avoids implicit junction tables & cascades
   - Index frequently filtered columns → Prisma can't auto-tune

```prisma
model Activity {
  id      String   @id @default(cuid())
  user    User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  type    ActivityType
  @@index([userId, type])
}
```

 - Testing
   - Framework: Vitest with `vitest.config.mts` shortcuts
   - Use `test.concurrent` for independent cases
   - AI integration tests suffixed with `.test.ai.ts` (skipped on standard CI)

```bash
yarn test         # all unit tests
yarn test:ai      # AI-powered cases only
```

 - Code Style
   - 2-space indent, single quotes, semicolons → Prettier (`.prettierrc.json`)
   - ESLint for lint+type rules → `eslint.config.js` extends `typescript-eslint`
   - Max line 100 chars (soft) → Improves diff readability
   - Additional: `invariant()` for runtime assumptions, `// TODO:` with context, links to docs in comments.

 - Security
   - Validate every external input → Zod schemas
   - Always verify JWTs; constant-time string compares
   - Sanitize DB inputs; prefer parameterised queries
   - Geoblocking & AI checks run before granting privileges

 - Performance
   - Redis for hot data → helper `redis.setex(key, ttlSecs, json)`
   - Batch DB writes & use `@@index` pragmatically
   - Memoize CPU-heavy selectors in React
   - Skip preflight on Solana txs where possible → measurable speed gain

 - Common Pitfalls
   - Prisma cascade deletes → Always specify `onDelete: Cascade` or explicit clean-up
   - Circular imports → Avoid barrel `index.ts` files; use direct paths

 - Starter Templates
   - New API Route
```typescript
import { withValidation } from '@/lib/request';
import { z } from 'zod';

const bodySchema = z.object({ ... });

export const POST = withValidation(async (_req, { body }) => {
  // business logic
  return Response.json({ ok: true });
}, { body: bodySchema });
```

   - New React Hook
```typescript
import { useState } from 'react';

export default function useFeature() {
  const [state, setState] = useState<FeatureState>();
  // ...
  return { state };  // expose stable object
}
```

 - Summary
   - Be Explicit → names, types, errors
   - Fail Fast → guard clauses, validation early
   - Handle Errors → classify & log appropriately
   - Stay Consistent → follow established patterns
   - Think Security → validate & authorise every request
   - Optimise Wisely → measure before tuning
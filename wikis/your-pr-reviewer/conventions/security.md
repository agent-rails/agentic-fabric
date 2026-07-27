# Security Conventions

## Input Validation
- TypeScript: Zod schemas for all external input
- Python: Pydantic v2 for all external input
- Never trust request payloads

## Authentication
- Always verify JWTs
- Constant-time string comparisons
- Geoblocking and AI checks run before granting privileges

## Data
- Parameterized queries (SQLAlchemy, Prisma)
- Sanitize/escape user-controlled strings
- Never hardcode secrets — use env vars

## Infrastructure
- Least-privilege IAM
- Rotate tokens regularly
- Read-only modes for production MCP servers

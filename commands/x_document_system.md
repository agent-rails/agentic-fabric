---
description: Document system architecture using C4 diagrams, sequence diagrams, and data flows
argument-hint: [system-or-feature-name]
---

Document the architecture for $ARGUMENTS using concise, maintainable diagrams and code anchors.

Output:
1) C4 – Container (Mermaid flowchart): external actors, trust boundaries, core services, data stores, secret stores, infra (API GW/NLB/VPC if cloud).
2) C4 – Component (focus service): controllers/routes, middleware, services, repos, external deps; show DB/Redis/queues/secret manager edges.
3) Sequence – Core processes: <core_process_names>; include authn/z, validation, rate limit, secret access, external calls, error mapping.
4) Data Flow: end users/agents → edge → service → caches/DB/queues/secrets → external systems; annotate key edges (CRUD, TTL, spawn, etc).

Also include:
- Security: authn/z model, input validation, rate limiting, error handling policy, logging/audit, least privilege. If keys/credentials: use secret manager (no local key files).
- Config: required env vars, ports, timeouts, feature flags.
- Infra: runtime (ECS/Fargate/K8s), gateway/ingress, VPC/boundaries.
- Code anchors: file paths per component/flow.
- Assumptions & out-of-scope.

Mermaid hygiene:
- Quote labels with spaces/special chars: Node["Label"], or Node("Label"); use <br/> for multi-line.
- Use [("DB")] for cylinder DB shape; keep edge labels quoted.
- Keep diagrams minimal, consistent, and valid.

Maintenance rule:
- Update diagrams and anchors in the same PR as any design/code change affecting architecture.

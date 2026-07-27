# Templates Fan-Out Versioning Discipline

Reusable workflows in `your-org/workflow-templates` (and any future template repo with N-consumer fan-out) follow a stricter versioning discipline than internal libraries because behavior changes propagate to every consumer pinned to the major.

## Rules

- **Default-on behavior changes are major bumps.** Adding a new gate, blocking step, or fail-closed path that runs by default is a `@v(N+1)`, never a default flip on `@vN`. This is true even when the surface change is additive (new inputs, new jobs).
- **New required behavior gates behind required inputs without defaults.** If `@v2` introduces a new input the consumer must pass to opt into the new code path, the consumer cannot end up on the new behavior accidentally. This is the safe migration shape.
- **Optional new behavior is opt-in via input default-off.** If the new behavior is not load-bearing (e.g., extra logging, optional security check), ship as a minor with the input default `off`; flip to `on` in the next major.
- **No silent default-flips on stable majors, ever.** Even a "safer" flip (e.g., adding a security check) breaks consumers whose CI conventions don't match the new contract. Major bumps are how blast radius gets bounded.
- **PR description on every template change must include a consumer-impact section.** What does a `@v1`-pinned consumer see if this merges? If the answer is "nothing" the change is safe; if anything else, it's a major bump.

## When This Applies

- `your-org/workflow-templates` — every reusable workflow.
- `your-org/charts` charts consumed by `your-org/gitops-config` — when chart values change required-set or default-on behavior.
- Any future shared GHA action / Helm chart / Terraform module with cross-repo fan-out.

## When This Does Not Apply

- Internal-only workflows pinned to a single consumer.
- Bug fixes that align actual behavior with documented behavior (the contract didn't change — the implementation now matches it).
- Vulnerability fixes where the alternative is a known live exploit.

## Why

A single template change at `@v1` propagates to N consumers on every merge. Adding default-on blocking behavior turns a correct fix into a coordinated outage. Major-bump discipline is how the platform team retains the ability to ship behavior changes at all without negotiating with every service team for every change.

## See Also

- `[[anti-patterns/default-on-blocking-behavior-on-major-version-pin]]` — what happens when this convention is violated
- `[[patterns/cross-repo-gate-trust-on-publisher]]` — the security-side companion: gates over conventions, structured inputs over regex defaults

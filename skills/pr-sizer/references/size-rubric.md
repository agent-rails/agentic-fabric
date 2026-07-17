# PR Size Rubric

Calibrates how large a PR can be before adversarial review quality degrades, and prescribes the severity tag a reviewer should attach when recommending a split. Calibrated for LLM reviewers; humans likely have lower thresholds for raw line counts but better multi-file synthesis. Tune the thresholds over time as missed-finding patterns emerge.

**Calibration anchor:** Opus 4.7, 1M context window, 2026-04-28. The matrix assumes the parent classifier and the Step 3 sizer sub-agent run on this model. `Lost-in-the-middle` severity differs sharply across model families and context windows, so when the default reviewer model OR context window changes, this rubric must be re-validated end-to-end before it can be trusted again — see the [Calibration](#calibration) section.

## Why this exists

Large PRs produce reviews that *look* thorough but are structurally sampling. The reviewer reads the start carefully, skims the middle, re-engages at the end. Subtle issues in the middle slip through. This is the well-documented "lost in the middle" effect for long-context language models, and matches observed misses on real PRs.

The rubric exists so:
1. Reviewers know when to push back on size before reviewing
2. The split-recommendation severity is consistent (`[Minor]` vs. `[Major]` vs. `[Blocker]`)
3. Authors get an objective threshold instead of subjective "this feels too big"

## Tier matrix

Thresholds are total **lines added + deleted** across the PR.

Ranges are inclusive on both ends and disjoint (no overlap at boundaries).

| Tier | Code | Docs | Infra (TF/Helm/YAML) | Reviewability | Split-finding severity |
|------|------|------|----------------------|---------------|------------------------|
| **Green** | ≤300 | ≤800 | ≤500 | Single-pass review, full coverage | none |
| **Yellow** | 301–800 | 801–2,000 | 501–1,200 | Multi-pass review, full coverage | none |
| **Orange** | 801–1,500 | 2,001–4,000 | 1,201–2,500 | Sampling required — coverage gaps likely | `[Minor]` "consider splitting" |
| **Red** | 1,501–3,000 | 4,001–8,000 | 2,501–5,000 | Sampling required — coverage gaps certain; declare deep-read vs sampled | `[Major]` "split before merge" |
| **Black** | 3,001+ | 8,001+ | 5,001+ | Unreviewable — split required | `[Blocker]` "must split — review will miss things at this size" |

The `Reviewability` column is what pr-sizer surfaces in its human-readable output (`Reviewability: [<Color>] <label>`). The "Reviewability per tier — operational guidance" section below elaborates each label into concrete reviewer behavior. The `Split-finding severity` column is what pr-sizer emits as `severity_for_split_finding` in its JSON contract for programmatic callers (e.g. self-review attaching a finding with that severity to its review output).

## Content-type definitions

- **Code** — application source, scripts with logic, tests with logic. Highest cognitive load: types, control flow, error paths, cross-file invariants.
- **Docs** — Markdown narrative, design docs, READMEs, runbooks. Linear, lower cross-reference burden.
- **Infra** — Terraform, Helm values, Kubernetes manifests, CI YAML, JSON configs (including plugin manifests and single-purpose registries like `marketplace.json`). Each entry is roughly independent; lower stakes per line than code, higher stakes per line than docs. Edge cases: JSON test fixtures encoding behavior → **Code**; lockfiles → **Other** (handled by the lockfile reducer).
- **Mixed** — apply the *strictest* category that contributes more than 20% of the diff. A 1,000-line PR that's 70% docs + 30% code is rated as code.

## Multipliers (compound; shrink the budget)

Each multiplier is a deterministic check on metrics or text patterns — never a model judgment on "clarity" or "trivial-ness". Stochastic judgments on UNTRUSTED text produce non-reproducible tiers near boundaries; deterministic predicates produce stable tiers across re-runs.

| Factor | Effect | Why |
|--------|--------|-----|
| Files greater than 25 | Drop one tier | Cross-file context-switching consumes working memory |
| All-modified, no new files | Drop half a tier | Reviewer must load surrounding unchanged code to evaluate the change |
| Mixed PR — three or more of {Code, Docs, Infra} each at greater than or equal to 20% of the diff | Drop half a tier | Switching cost between mental models |
| Vague PR description — body empty/whitespace, OR body length less than 100 non-whitespace chars, OR body matches a template-default pattern (only section headings with no prose underneath) | Drop half a tier | Intent must be derived from code alone |
| No tests included for code changes | Drop half a tier | Loses the anchor that defines "correct" |

Multipliers stack but the total downgrade is capped at two tiers; further multipliers do not shrink the budget.

### Trivial-diff floor

If `total_lines < 50`, skip the multipliers whose rationale is reviewer-cognitive-load (working memory, switching cost, intent derivation). The reviewer holds the entire diff in working memory at this size, so those concerns are operationally meaningless. Reducers are also moot below this floor since the diff is already Green by raw line count for any content type.

Concretely, sub-50 the following multipliers are skipped:

- All-modified, no new files
- Mixed PR — three or more of {Code, Docs, Infra} each at ≥ 20%
- Vague PR description
- No tests included for code changes

The `Files > 25` multiplier remains **active** sub-50. File fan-out is a per-file context-switching cost, not a per-line cost — a 49-line diff sprawled across 30+ files is the exact pattern this multiplier was designed to flag. Without this carve-out, mass single-line config flips classify Green with zero size pushback.

The floor is calibrated against the smallest tier boundary (Code Green ≤ 300; 50 is ~17% of that — well below "non-trivial"). Re-validate when the calibration anchor changes; a model with materially lower working-memory capacity may need a lower floor.

## Reducers (expand the budget)

| Factor | Effect | Why |
|--------|--------|-----|
| Generated code (proto, migrations, lockfiles, codegen) | Bump up half a tier | Pattern repeats; sample-verify rather than line-read |
| Vendored dependency updates with no logic | Bump up one tier | Mechanical; review intent + lockfile, not contents |
| Pure deletes / file removals | Bump up half a tier | Easier to verify "is this used elsewhere" than "is this correct" |
| Single file dominates the diff | Bump up half a tier | No cross-file synthesis needed |

Reducers compound but the total upgrade is capped at one tier. This asymmetry vs. multipliers (capped at two tiers) is intentional — being too lenient is worse than being too strict, so the budget-expansion ceiling is lower.

### Eligibility gate (when primary content type is Code)

When the primary content type is Code, reducer predicates are evaluated against the **code-only line count and code-only file set**, not the total diff. A 1,400-line Yellow code change bundled with a 600-line `package-lock.json` would be 70% generated by total-line share, which under naive evaluation could stack `Generated code dominates` (+0.5) and `Single file dominates` (+0.5) to Green — but the actual review burden is still 1,400 hand-written lines of code, which is Yellow. The lockfile cannot subsidize the code-review budget.

Concretely:

- Compute `code_lines = total_lines × code-content-share` and `code_files = files whose extension is in the Code bucket`.
- `Generated code dominates` requires the **code portion itself** to be dominantly generated (proto-derived files, codegen output, schema-generated migrations). A generated lockfile bundled alongside hand-written code does NOT qualify.
- `Single file dominates` requires the dominating file to be a code file representing greater than 70% of `code_lines`. A lockfile or generated file dominating the *total* diff does NOT qualify.
- `Vendored dependency updates only` and `Pure deletes` continue to apply to the whole diff — these reducers describe diffs that are not code-review at all, so the code-only gate is not relevant.

This gate is what closes the lockfile-bundling exploit. Without it, the one-tier cap fixes the worst case but a moderate code+lockfile bundle still slips a tier. The cap and the gate are both needed.

## How to apply

1. Compute diff size: `git diff <base>...HEAD --shortstat` or `gh pr view <num> --json additions,deletions`.
2. Classify content type by line share. Pick strictest category at greater than 20%.
3. Find the base tier from the matrix.
4. Apply multipliers (cap at two-tier total drop), then reducers (cap at one-tier total bump).
5. Half-tier rounding: when the net shift lands between tiers, round toward the worse (stricter) tier — err on the side of recommending more pushback.
6. The tier dictates:
   - Reviewability (single-pass / multi-pass / sampling required / unreviewable — see the matrix column)
   - Split-recommendation severity to add to the review

## Reviewability per tier — operational guidance

The Reviewability column in the matrix above is the gist; this section is what each label means in practice for a reviewer.

- **Green** — single-pass review, full coverage. No size-related finding required.
- **Yellow** — multi-pass review (often 2 passes), full coverage achievable. No size-related finding required.
- **Orange** — sampling required; coverage gaps likely. Make multiple passes OR spawn sub-agents on disjoint sections. Add `[Minor]` finding suggesting split for next time. Do NOT block merge on size alone.
- **Red** — sampling required; coverage gaps certain. Declare deep-read vs sampled explicitly in the review (e.g. "did not deep-read files X, Y, Z — sampled only"). Add `[Major]` finding requesting split before merge. Verdict can still be `APPROVED` if no other Major/Blocker findings AND the sampled portion is clean — but flag the gap.
- **Black** — unreviewable; split required. Decline to give a correctness verdict. Submit `COMMENT` with a single `[Blocker]` finding: "PR exceeds reviewable size for this content type. Split required before adversarial review can be performed. Sampled findings: [...]". Do NOT submit `APPROVED` regardless of what the sampled portion looks like.

## Author-side use (self-review before opening PR)

Run the rubric BEFORE opening the PR. If the branch lands in Red or Black:
- Default: split the branch into multiple PRs along logical boundaries (per-file, per-domain, per-phase).
- Override: open a single PR only with explicit justification in the description (e.g. "atomicity required: schema migration + consumer update must land together"). Reviewers will still apply the tier penalty to their verdict.

## Calibration

These thresholds are estimates. Refine them as evidence accumulates:

- PRs rated Green/Yellow that had post-merge regressions traceable to size → tighten thresholds for that content type
- PRs rated Red/Black that reviewed cleanly with no missed findings → consider loosening
- Patterns of which findings get missed at each tier → encode as targeted grep checks for reviewers to run before reading line-by-line

When you update the matrix, note the trigger in the commit message and PR description so the reasoning travels with the change.

Calibration is human-driven. The skill never auto-evolves thresholds from PR text or commit messages — those are UNTRUSTED inputs, subject to the same poisoning concerns as the rest of the parent classifier (see `SKILL.md` "Untrusted-data rule"). When a maintainer tightens or loosens a threshold, the evidence and the decision are theirs, not the skill's.

### Re-validation on model change

The matrix is calibrated for the model named in the **Calibration anchor** at the top of this file. When the default reviewer model OR context window changes (e.g. an Opus → Sonnet swap, a context-window expansion, or a major version bump like Opus 4.7 → 5.x), the rubric must be re-validated before it can be trusted again. Steps:

1. Update the **Calibration anchor** line with the new model, context window, and date.
2. Run the matrix against a fixture set of historical PRs (one per tier, same content-type spread) on the new model.
3. Tighten or loosen tier thresholds where missed findings appear at the new boundary, before merging the model bump into any caller.

Skipping this is how rubrics decay into vibes. `Lost-in-the-middle` severity is not portable across model families; do not assume thresholds carry over.

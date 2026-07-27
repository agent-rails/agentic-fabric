---
title: Helm / Go-template review checklist
type: convention
status: active
---

## Why this exists

On PRs touching Helm charts (especially ones that introduce new Helm values, refactor templatePatch blocks, or parameterize previously-hardcoded values), the standard "read the diff and reason about it" review pass routinely misses a small set of edge cases that are obvious to a human running `helm template` / `helm unittest` locally.

Three lessons from real PR reviews where the cross-vendor pass missed real bugs that human review caught:

1. **A `notMatchRegex` test assertion passed vacuously** because the regex was too broad and matched an adjacent destination-routing block. Static reasoning didn't catch it; running `helm unittest` did (1 failed, 7 passed).
2. **A new `.Values.provider.lockEnabled` reference broke `--set provider=null`** with a nil-pointer panic. Pre-existing consumers using `provider=null` silently broke.
3. **A new `previewEnv` value was interpolated raw into a Go-template string literal** inside `templatePatch`. A value containing `"` breaks the rendered Go template and halts ApplicationSet rendering.

This checklist is the codified version of those misses. Reviewers reviewing chart PRs should walk it explicitly.

## Checklist

### 1. Execute, don't just read

If the PR touches a Helm chart that has `tests/*_test.yaml` (helm-unittest), **run the tests**:

```bash
helm unittest charts/<chart>
```

Static reasoning about regex assertions and template-string shape catches gross errors. Runtime execution catches subtle ones.

### 2. Boolean-ish values

Go templates treat **any non-empty string as truthy**. A chart value declared as a boolean but set by a consumer as the string `"false"` silently enables the feature.

When you see a new boolean value introduced, check the consuming template for normalization with the `eq (lower (printf "%v" $v)) "true"` pattern.

### 3. Nil-guard on optional values

If the PR adds a new `.Values.foo.bar` reference, check whether `foo` was previously optional. Consumers who use `--set foo=null` will hit a nil-pointer panic.

Verify:
```bash
helm template t charts/<chart> --set <addedSection>=null
```

### 4. Raw interpolation into Go-template literals

When a Helm value is interpolated into a string that **itself contains Go-template syntax** (e.g., ApplicationSet's `templatePatch`), a value containing `"`, `{{`, `}}` breaks the inner template.

Validate at chart render time with a fail-fast helper (regex constraint).

### 5. Doc-vs-code parameterization consistency

When the PR introduces a new chart value as a parameter, audit every doc reference that may still have the prior hardcoded literal. Grep for the prior literal across README, in-template comments, values.yaml inline docs.

### 6. `--set` vs `--set-string`

For new boolean values, test both modes — if the chart works under `--set` but breaks under `--set-string`, you have a normalization gap.

### 7. Backward compat for existing consumer pins

If consumers pin via semver-range, breaking defaults inherit silently. For breaking defaults, add an opt-in flag (existing default = old behavior) OR bump major version.

## Incidents this checklist would have caught

- PR your-org/charts#73 cycle-3 review (2026-05-21): all 5 findings + 1 nit caught by human reviewer running `helm unittest` + enumerating value-space edge cases; none caught by static cross-vendor pass.

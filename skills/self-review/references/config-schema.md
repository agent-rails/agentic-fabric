# `.self-review.yaml` — config schema

This document defines the configuration format for the `self-review` skill.

## Format

YAML, parsed in three explicit phases. Lens frontmatter (see `references/lens-template.md`) is parsed under the same rules.

**Phase 1 — pre-parse text scan.** Before any parser sees the bytes, reject the raw YAML text if any of:
- Document size exceeds 64 KiB.
- Any explicit tag syntax appears (e.g. `!foo`, `!!str`, `!!int`, `!!timestamp`, `!!binary`). `yaml.safe_load` accepts standard YAML 1.1/1.2 tags by default; the orchestrator strips them out via this pre-parse scan.
- The merge key (`<<:`) appears.
- Anchor count (`&name`) exceeds 16.

**Phase 2 — parse.** Use PyYAML `yaml.safe_load` (or an equivalent loader that does NOT invoke custom constructors). `safe_load` is the parser; the pre-parse scan above is what closes the standard-tag and merge-key gaps `safe_load` leaves open.

**Phase 3 — post-parse validation.** After parse, reject the document if:
- Any custom constructor was invoked during parse (sanity check).
- Total node count exceeds 5000.
- Any string value exceeds 16 KiB.
- Any field's parsed type doesn't match the declared schema type — closes YAML 1.1 implicit coercions (`yes` / `on` / `1:30` etc. silently coerced to `bool` / `int` / etc.). For example, `lenses.adversarial` MUST parse to a string `enabled` or `disabled`; if it parses to `bool True` because the user wrote `on`, reject with a specific error.

The orchestrator MUST enforce all three phases, halting with a specific violation message before merging the config.

Plugin manifests (`plugin.json`, `marketplace.json`) remain JSON; that is unchanged.

## Locations

Resolution order, later wins on the same key:

1. **Shipped defaults** — built into the plugin
2. **Repo config** — `.self-review.yaml` at the root of the repo being reviewed (team-shared, checked in)
3. **User config** — `~/.config/self-review/config.yaml` (user-scoped, never checked in)

Missing config files are not errors. The skill falls back to the next layer in the chain.

## Schema

```yaml
# Gate behavior. pr-sizer always runs; only the response to a Black tier is configurable.
gates:
  pr-sizer: required          # required | optional

# Lenses to run. Keys are lens names; values are `enabled` or `disabled`.
# Custom lenses must also be declared here to take effect.
lenses:
  adversarial: enabled        # shipped default lens
  # cost-optimization: enabled  # uncomment to add a custom lens

# Where to look for custom lenses. Paths are searched in order.
# Repo-config paths MUST be repo-relative (no `..`, no `~`, no absolute paths).
# User-config paths MAY use `~` ($HOME) or absolute paths.
custom_lens_dirs:
  - .self-review/lenses                    # repo-local team lenses
  - ~/.config/self-review/lenses           # user-scoped lenses (user config only)
```

## Gate values

| Value | Meaning |
|-------|---------|
| `required` | Default. Green/Yellow/Orange proceed (Orange attaches a `[Minor]` size finding). Red proceeds with a `[Major]` size finding flagged in output. Black halts; lenses do not dispatch. |
| `optional` | Green/Yellow/Orange/Red behave identically to `required`. Only Black changes: lenses dispatch, and a `[Blocker]` size finding is attached instead of halting. |

`gates.pr-sizer` controls dispatch and the body of the Black-halt-path size finding; pr-sizer's own classification block is unconditionally suppressed inside self-review regardless of gate value. Specifically: on the `tier == "Black" + gate == "required"` halt path, the orchestrator-appended size finding inlines `lines.total`, `files`, `commits`, and `content_type` in `<problem>` text so the reviewer sees the numbers without rerunning pr-sizer (per `SKILL.md` Step 1); on any other path (including `tier == "Black" + gate == "optional"` and all non-Black tiers), the size finding renders as a regular item without the inline metrics. Inside a self-review run, pr-sizer's classification block (the `## Size classification` heading, the `Lines:`/`Files:`/`Content type:`/`Reviewability:` lines, and the fenced JSON) is suppressed and replaced by the single tier line described in `SKILL.md`'s "Narration discipline" section; pr-sizer's standalone invocation continues to render its own classification block as before.

## Lens enablement rules

- A lens listed as `enabled` runs.
- A lens listed as `disabled` does not run, **except** for shipped default lenses — see "Repo cannot disable shipped defaults" below.
- A lens not listed at all → defaults run; custom lenses do NOT run.
- Empty `lenses: {}` dict (key present but no entries) behaves identically to a missing `lenses` key: defaults run, custom lenses do NOT run. To disable a shipped default lens, the user MUST list it explicitly with `disabled` (and even then, only the user config can disable defaults — see below).
- Reserved default lens names (canonical list below) cannot be redefined regardless of shipped state. **The reservation check runs before merge-and-override.** A repo or user config attempting to define or enable a custom lens with one of those names produces a hard error, regardless of resolution-order layering — reservations are immutable.

  **Canonical reserved-name list** (single source of truth — other references link here):
  - `adversarial` — shipped
  - `engineering` — shipped
  - `security` — reserved for future toolkit default

  The toolkit may add more reserved names over time; this list is the authoritative copy.
- A `verdict: included` lens with `max_severity` below `Major` is rejected at load time with a clear error: this combination silently disarms the lens's veto and is almost always a mistake. Use `verdict: findings_only` if the lens should not block, or raise the ceiling.
- **Repo cannot disable shipped defaults.** `.self-review.yaml` MAY enable additional custom lenses, set `gates.pr-sizer`, and add `custom_lens_dirs`. It MAY NOT set `disabled` on any shipped default — that key is silently ignored at the repo layer (with a parser warning surfaced in the run output). Only the user config (`~/.config/self-review/config.yaml`) can disable a shipped default. Rationale: in remote-PR mode the target repo's config is attacker-controlled; without this rule, a hostile repo could disable the security lens for everyone reviewing their PR. **Deferred:** the user-config disable path is doc-only today — `.self-review.yaml` consumption beyond `gates.pr-sizer` is deferred (see `SKILL.md` "Active state" and "Deferred"), so neither repo nor user lens enable/disable state is consumed by the runtime yet. The rule above is the contract for when that consumption activates; until then, shipped defaults always run regardless of any `disabled` declaration in either layer.
- **Cross-layer trust rule.** Only the config layer that contributed a `custom_lens_dirs` entry may enable lenses found within it. Repo-config can enable lenses living in repo-config-listed dirs; user-config can enable lenses living in user-config-listed dirs. Shipped defaults are exempt and may be enabled from any layer. This prevents a hostile repo from enabling code shipped by the user (or vice versa).
- **`custom_lens_dirs` path overlap across layers.** If repo and user configs both list the same `custom_lens_dirs` entry (after canonical-path normalization via `realpath`), the entry is attributed to the user layer. Only user-layer enables can target lenses in that dir; repo-layer enables fail with `lens not enabled by its own layer`. Rationale: when in doubt, give the trust to the user, not the repo.
- Lens-name collision detection applies only to lenses that resolve to enabled state. Two `cost-optimization.md` files in different `custom_lens_dirs` are only a collision error if `cost-optimization` is enabled in the merged config.

### `custom_lens_dirs` constraints

- **Repo config (`.self-review.yaml`):** entries MUST be literal repo-relative paths. Absolute paths, `..` segments, `~` expansion, and Unicode-normalization tricks are rejected at load with a hard error. After lexical validation, the orchestrator resolves each entry via `realpath` and rejects entries whose canonical path is not a descendant of the repo root's canonical path — this catches symlinks where the dir entry itself points outside the repo.
- **User config (`~/.config/self-review/config.yaml`):** entries MAY use `~`, absolute paths, and any directory the user has read access to.
- **Recursion: non-recursive.** Only `*.md` files directly inside each listed dir are scanned. Subdirectories are ignored. This keeps the scanner's blast radius bounded and aligns with the realpath check (which is cheap to do once per dir, not per recursive descendant).
- **Per-file open posture.** When loading a lens file the orchestrator opens with `O_NOFOLLOW` (or equivalent) and re-validates that the resolved file still lives under the dir's realpath, closing TOCTOU between scan and read.
- Rationale: a repo-checked config controls a path-traversal vector against the user; the cross-layer trust rule and the realpath-and-reopen contract close the symlinked-dir, TOCTOU, and lens-from-other-layer attacks together.

## Example: minimal repo config

```yaml
# .self-review.yaml at repo root
# Shipped defaults run automatically; this example enables an additional custom lens
lenses:
  team-conventions: enabled   # custom lens defined under .self-review/lenses/team-conventions.md
```

## Example: user config with custom lens

```yaml
# ~/.config/self-review/config.yaml
custom_lens_dirs:
  - ~/.config/self-review/lenses

lenses:
  personality-hacker: enabled
```

`personality-hacker` resolves to `~/.config/self-review/lenses/personality-hacker.md`. Lens names use only `[a-z0-9-]` (see `references/lens-template.md`); group/category prefixes are encoded directly with hyphens (e.g. `personality-hacker`, `domain-postgres`, `style-terraform`) — no separator translation. The on-disk name and the config-key name are the same string.

## Example: relaxed gate

```yaml
# .self-review.yaml at repo root for a doc-heavy repo
gates:
  pr-sizer: optional          # 5,000-line doc PRs are normal here; don't halt on Black
# lenses block omitted — defaults run automatically (currently `adversarial`)
```

## Validation

The orchestrator validates the merged config before dispatch. Errors halt with a clear message:

- Unknown gate name → `unknown gate: <name>`
- Unsupported gate value → `gate <name> does not support value: <value>`
- Lens enabled but not findable → `lens not found: <name> (searched: <dirs>)`
- Lens name collision (enabled lens defined in two dirs) → `lens collision: <name> defined in <path-a> and <path-b>`
- Custom lens redefining a reserved default lens name → `lens name reserved: <name> is a reserved default lens name and cannot be redefined`
- Cross-layer trust violation (config layer enables a lens found only in another layer's dirs) → `lens not enabled by its own layer: <name> lives in <user|repo> dirs but is enabled by <repo|user> config`
- Lens name not matching `^[a-z0-9][a-z0-9-]*[a-z0-9]$` → `invalid lens name: <name> (allowed: lowercase letters, digits, hyphens; no leading/trailing hyphen)`
- `verdict: included` with `max_severity` below `Major` → `lens contract violation: <name> declares verdict: included with max_severity: <value> — this silently disarms the veto; use verdict: findings_only or raise the ceiling`
- `max_duration_seconds` outside 60–600 → `lens duration out of range: <name> declares <value>s (allowed 60–600)`
- Repo-config `custom_lens_dirs` containing absolute path / `..` / `~` / non-canonical entry / symlink escaping the repo → `repo-config custom_lens_dirs must be repo-relative and stay inside the repo: rejected entry <path>`
- Lens frontmatter `name` not equal to filename minus `.md` → `lens name mismatch: file <path> declares name <name>, expected <basename>`
- Malformed YAML → underlying parser error verbatim
- YAML safe-load violation (tag, custom constructor, merge key, oversized doc, anchor-count or node-count exceeded, oversized string) → halt with the specific violation

## Scope

The config controls which lenses run and how the size gate responds to over-large PRs. It does not control:

- **Lens-internal behavior** — timeout (`max_duration_seconds`) and severity ceiling (`max_severity`) are declared in the lens file itself. The lens author owns these; the config consumer does not override them.
- **Read-only posture** — the skill never posts comments or submits reviews. No config value changes that.
- **Output structure** — verdict and per-lens findings sections are the contract this skill produces. Alternative renderings live in separate skills, not config flags.

# Architecture Decision Records

One file per load-bearing choice. Each records the context, the options weighed, the decision, and its consequences — so a future reader (or a future me) can tell whether a change is revisiting a settled tradeoff or breaking one blindly.

Format is lightweight [MADR](https://adr.github.io/madr/)-style. These are reconstructed from the shipped artifacts (prompts, wikis, hooks) and the reasoning encoded in them; where a record states a rationale the code implies but doesn't prove, it says so.

| ADR | Decision | Status |
|-----|----------|--------|
| [0001](0001-model-tiering.md) | Model tiering — opus for judgment, haiku/sonnet for mechanics | Accepted |
| [0002](0002-user-is-orchestrator.md) | The user (or a slash command) is the orchestrator; personas don't chain | Accepted |
| [0003](0003-wiki-as-memory.md) | Git-backed markdown wikis as persistent agent memory | Accepted |
| [0004](0004-hooks-over-prompts.md) | Hooks over prompts for rules that must not be skipped | Accepted |
| [0005](0005-cross-vendor-cascade.md) | Cross-vendor review cascade, bounded by a convergence cap | Accepted |
| [0006](0006-outbound-human-gate.md) | Outbound actions (send/merge/push) are always human-gated | Accepted |

## Writing a new ADR

Add one when a change trades one design principle against another, or reverses a decision recorded here. Number sequentially. Keep it to: Context → Options → Decision → Consequences. If you can't name the option you *didn't* pick and why, you're not ready to write it yet.

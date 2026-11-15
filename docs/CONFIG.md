# Configuration

Every module reads its settings in this order:

1. The plugin option you set when enabling the plugin. Claude Code passes it to hooks as `CLAUDE_PLUGIN_OPTION_<KEY>`.
2. The plugin's section of `~/.config/agentic-fabric/config.json`.
3. The built-in default.

A setting marked required has no default. Until it is set, the hook that needs it refuses the action it guards and says how to set it; nothing else is affected.

A config file that is not valid JSON, is not an object, or holds a non-scalar value is an error, never a silent default. `fabric-gates` protects the file itself, so an agent cannot change it without your unlock.

## Example file

```json
{
  "fabric-gates": {
    "branch_prefix": "me/",
    "protected_paths": "notes/review-rubric, standards/review.md",
    "gate_unlock_minutes": 15
  }
}
```

## fabric-gates

| Key | Type | Default | Meaning |
|---|---|---|---|
| `branch_prefix` | string | required | Prefix for every branch the agent creates. |
| `protected_paths` | string | empty | Comma-separated paths relative to your home directory, added to the built-in protected set. Absolute paths and `..` are rejected, and the gate then fails closed. |
| `gate_unlock_minutes` | number | 15 | Lifetime of `~/.claude/gate-unlock`. Clamped to 1-60; a non-number falls back to 15. |

Settings are versioned with the release. Before `1.0.0` a key may change; the release notes say so.

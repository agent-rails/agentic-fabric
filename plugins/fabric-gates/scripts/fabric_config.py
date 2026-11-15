#!/usr/bin/env python3
"""Read one agentic-fabric setting.

Lookup order: the plugin option Claude Code exports to hooks
(CLAUDE_PLUGIN_OPTION_<KEY>), then the plugin's section of the local file
~/.config/agentic-fabric/config.json ({"fabric-gates": {"branch_prefix": ...}}),
then the caller's default. A required
key that is missing everywhere, or a config file that is not a JSON object,
raises ConfigError: a hook turns that into a deny that names the fix, never a
silent default.

CLI: fabric_config.py get <plugin> <key> [--default VALUE] [--required]
Prints the value. Exit 2 with the reason on stderr when it cannot.

Every plugin ships an identical copy of this file, because a plugin's install
directory holds only its own files.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ENV_PREFIX = "CLAUDE_PLUGIN_OPTION_"


class ConfigError(Exception):
    pass


def config_path() -> Path:
    return Path(os.environ.get("AGENTIC_FABRIC_CONFIG", Path.home() / ".config" / "agentic-fabric" / "config.json"))


def _file_values(path: Path, plugin: str) -> dict:
    if not path.exists():
        return {}
    try:
        values = json.loads(path.read_text())
    except ValueError as err:
        raise ConfigError(f"{path} is not valid JSON ({err})") from err
    if not isinstance(values, dict):
        raise ConfigError(f"{path} must hold a JSON object, not {type(values).__name__}")
    section = values.get(plugin, {})
    if not isinstance(section, dict):
        raise ConfigError(f"{path}: '{plugin}' must be an object of settings")
    return section


def get(plugin: str, key: str, default: str | None = None, required: bool = False) -> str | None:
    env_name = ENV_PREFIX + key.upper()
    from_env = os.environ.get(env_name, "")
    if from_env:
        return from_env
    path = config_path()
    values = _file_values(path, plugin)
    if key in values:
        value = values[key]
        if not isinstance(value, (str, int, float, bool)):
            raise ConfigError(f"{path}: {plugin}.{key} must be a string, number or boolean")
        return str(value).lower() if isinstance(value, bool) else str(value)
    if default is None and required:
        raise ConfigError(
            f"setting '{key}' is not set: set the plugin option, the {env_name} environment variable, or '{key}' under '{plugin}' in {path}"
        )
    return default


def main(argv: list[str]) -> int:
    if len(argv) < 3 or argv[0] != "get":
        print("usage: fabric_config.py get <plugin> <key> [--default VALUE] [--required]", file=sys.stderr)
        return 2
    plugin, key, rest = argv[1], argv[2], argv[3:]
    default = None
    if "--default" in rest:
        index = rest.index("--default")
        if index + 1 >= len(rest):
            print("--default needs a value", file=sys.stderr)
            return 2
        default = rest[index + 1]
    try:
        value = get(plugin, key, default=default, required="--required" in rest)
    except ConfigError as err:
        print(f"agentic-fabric: {err}", file=sys.stderr)
        return 2
    if value is not None:
        print(value)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

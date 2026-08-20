#!/usr/bin/env bash
# Sync canonical shared-wiki pages (repo) -> deployed copy (~/.claude/shared-wiki),
# applying placeholder -> real-name substitution.
#
# The repo copy is canonical and uses generic placeholders (your-pr-reviewer,
# your-triage-agent, ...). The deployed copy uses your real agent names. The
# substitution map that bridges them lives OUTSIDE the repo (default
# ~/.claude/shared-wiki/.sync-map) so real names are never committed. Copy
# scripts/sync-shared-wiki.map.example to that path and fill in your names.
#
# Guarantees:
#   - substitution is applied longest-placeholder-first (no partial-token clobber)
#   - fail loud if any mapped placeholder survives into the output (incomplete sub)
#   - never clobber a target that was hand-edited since the last sync
#     (checksum recorded in .sync-state; mismatch -> warn + skip)
#   - idempotent: running twice produces byte-identical output
#
# Env overrides (used by the test harness):
#   SYNC_SRC   source dir            (default: <repo>/shared-wiki)
#   SYNC_DEST  destination dir       (default: ~/.claude/shared-wiki)
#   SYNC_MAP   substitution map file (default: $SYNC_DEST/.sync-map)
#   SYNC_STATE checksum state file   (default: $SYNC_DEST/.sync-state)

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SYNC_SRC=${SYNC_SRC:-"$SCRIPT_DIR/../shared-wiki"}
SYNC_DEST=${SYNC_DEST:-"$HOME/.claude/shared-wiki"}
SYNC_MAP=${SYNC_MAP:-"$SYNC_DEST/.sync-map"}
SYNC_STATE=${SYNC_STATE:-"$SYNC_DEST/.sync-state"}

die() { echo "sync-shared-wiki: $*" >&2; exit 1; }

[ -d "$SYNC_SRC" ] || die "source dir not found: $SYNC_SRC"
[ -f "$SYNC_MAP" ] || die "substitution map not found: $SYNC_MAP (copy scripts/sync-shared-wiki.map.example there and fill in real names)"

mkdir -p "$SYNC_DEST"

checksum() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

update_state() {
  local name=$1 sum=$2 tmp
  tmp=$(mktemp)
  if [ -f "$SYNC_STATE" ]; then grep -vE "^${name}	" "$SYNC_STATE" > "$tmp" || true; fi
  printf '%s\t%s\n' "$name" "$sum" >> "$tmp"
  mv "$tmp" "$SYNC_STATE"
}

# Load map, longest placeholder first so shorter keys can't clobber longer tokens.
sed_args=()
placeholders=()
while IFS= read -r line; do
  ph=${line%%=*}
  real=${line#*=}
  [ -z "$ph" ] && continue
  sed_args+=(-e "s|${ph}|${real}|g")
  placeholders+=("$ph")
done < <(grep -vE '^[[:space:]]*(#|$)' "$SYNC_MAP" | awk -F= 'NF>=2 {print length($1)"\t"$0}' | sort -rn | cut -f2-)

[ ${#placeholders[@]} -gt 0 ] || die "no substitution entries parsed from $SYNC_MAP"

synced=0
skipped=0
for src in "$SYNC_SRC"/*.md; do
  [ -e "$src" ] || die "no .md files in $SYNC_SRC"
  name=$(basename "$src")
  dest="$SYNC_DEST/$name"

  tmp=$(mktemp)
  sed "${sed_args[@]}" "$src" > "$tmp"

  for ph in "${placeholders[@]}"; do
    if grep -qF -- "$ph" "$tmp"; then
      rm -f "$tmp"
      die "substitution incomplete: placeholder '$ph' still present in $name after sync"
    fi
  done

  recorded=$(awk -v f="$name" '$1==f{print $2}' "$SYNC_STATE" 2>/dev/null || true)
  if [ -f "$dest" ] && [ -n "$recorded" ]; then
    cur=$(checksum "$dest")
    if [ "$cur" != "$recorded" ]; then
      echo "sync-shared-wiki: SKIP $name — target modified since last sync (checksum mismatch); not clobbering" >&2
      rm -f "$tmp"
      skipped=$((skipped + 1))
      continue
    fi
  fi

  mv "$tmp" "$dest"
  update_state "$name" "$(checksum "$dest")"
  synced=$((synced + 1))
done

echo "sync-shared-wiki: synced $synced, skipped $skipped -> $SYNC_DEST"

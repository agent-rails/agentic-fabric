#!/usr/bin/env bash
# Tests for sync-shared-wiki.sh. No test framework in this repo (these are
# shell hooks/scripts) — this is a self-contained bash harness, run directly:
#   bash scripts/sync-shared-wiki.test.sh
# Exits non-zero on first failure.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SYNC=$SCRIPT_DIR/sync-shared-wiki.sh

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok - $*"; }

setup() {
  rm -rf "$WORK"/src "$WORK"/dest
  mkdir -p "$WORK"/src "$WORK"/dest
  cat > "$WORK"/src/page.md <<'EOF'
your-pr-reviewer synthesizes; your-pr-review-fetcher pulls the diff.
your-triage-agent triages; your-triage-fetcher fans out per channel.
EOF
  cat > "$WORK"/map <<'EOF'
your-pr-reviewer=realsent
your-pr-review-fetcher=realsent-fetcher
your-triage-agent=realvolt
your-triage-fetcher=realvolt-fetcher
EOF
  export SYNC_SRC="$WORK/src" SYNC_DEST="$WORK/dest" \
         SYNC_MAP="$WORK/map" SYNC_STATE="$WORK/dest/.state"
}

# 1. Substitution correctness — placeholders become real names.
setup
bash "$SYNC" >/dev/null
grep -q 'realsent synthesizes' "$WORK"/dest/page.md || fail "reviewer not substituted"
grep -q 'realsent-fetcher pulls' "$WORK"/dest/page.md || fail "fetcher not substituted"
grep -q 'realvolt triages' "$WORK"/dest/page.md || fail "triage not substituted"
ok "substitution correctness"

# 2. Round-trip completeness — no mapped placeholder survives in output.
for ph in your-pr-reviewer your-pr-review-fetcher your-triage-agent your-triage-fetcher; do
  if grep -qF "$ph" "$WORK"/dest/page.md; then fail "placeholder '$ph' left literal in output"; fi
done
# and the script fails loud if a substitution reintroduces a placeholder token:
setup
printf 'beta\n' > "$WORK"/src/page.md
printf 'your-triage-agent=realvolt\nbeta=your-triage-agent\n' > "$WORK"/map
if bash "$SYNC" >/dev/null 2>&1; then fail "expected loud failure when a substitution leaves a placeholder literal"; fi
ok "round-trip completeness (and fail-loud on surviving placeholder)"

# 3. Refuse to clobber a hand-edited target.
setup
bash "$SYNC" >/dev/null
echo 'HAND EDIT' >> "$WORK"/dest/page.md
before=$(cat "$WORK"/dest/page.md)
bash "$SYNC" >/dev/null 2>"$WORK"/warn
after=$(cat "$WORK"/dest/page.md)
[ "$before" = "$after" ] || fail "hand-edited target was clobbered"
grep -q 'SKIP' "$WORK"/warn || fail "no skip warning emitted for modified target"
ok "refuse to clobber manually-modified target"

# 4. Idempotency — running twice yields byte-identical output.
setup
bash "$SYNC" >/dev/null
sum1=$(shasum -a 256 "$WORK"/dest/page.md | awk '{print $1}')
bash "$SYNC" >/dev/null
sum2=$(shasum -a 256 "$WORK"/dest/page.md | awk '{print $1}')
[ "$sum1" = "$sum2" ] || fail "output changed on second run (not idempotent)"
ok "idempotency"

echo "all $pass tests passed"

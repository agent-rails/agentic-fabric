#!/usr/bin/env bash
set -uo pipefail

# See scan-write-content.sh for why: Claude Code / interactive shells don't
# always share PATH, and guard lives in ~/.local/bin via pipx.
export PATH="$HOME/.local/bin:$PATH"

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

POLICY="${SCAN_SKILL_POLICY:-$HOME/.claude/policies/write-content-scan.yaml}"

if [ $# -lt 1 ]; then
    printf "${RED}Usage: %s <skill-file-path>${RESET}\n" "$0"
    exit 1
fi

SKILL_FILE="$1"

if [ ! -f "$SKILL_FILE" ]; then
    printf "${RED}Error: File not found: %s${RESET}\n" "$SKILL_FILE"
    exit 1
fi

printf "${BOLD}Scanning skill file: %s${RESET}\n\n" "$SKILL_FILE"

HIGH_COUNT=0
MEDIUM_COUNT=0

report() {
    local severity="$1"
    local description="$2"
    case "$severity" in
        HIGH)   HIGH_COUNT=$((HIGH_COUNT + 1));   printf "${RED}[HIGH]${RESET} %s\n" "$description" ;;
        MEDIUM) MEDIUM_COUNT=$((MEDIUM_COUNT + 1)); printf "${YELLOW}[MEDIUM]${RESET} %s\n" "$description" ;;
    esac
}

# --- Structural checks that do NOT migrate to the shared policy engine ---
# guard's Policy engine evaluates one flattened, rendered string -- it has
# no concept of "line 1" or "inside YAML frontmatter." These two checks are
# inherently line-anchored / frontmatter-aware and stay here, per
# policies/write-content-scan.yaml's own header comment (search that file
# for "NOT migrated, deliberately" before ever deleting these).
LINE_NUM=0
IN_FRONTMATTER=0
while IFS= read -r line || [ -n "$line" ]; do
    LINE_NUM=$((LINE_NUM + 1))

    if [ "$LINE_NUM" -eq 1 ] && printf '%s' "$line" | grep -qE '^\-\-\-\s*$'; then
        IN_FRONTMATTER=1
        continue
    fi
    if [ "$IN_FRONTMATTER" -eq 1 ] && printf '%s' "$line" | grep -qE '^\-\-\-\s*$'; then
        IN_FRONTMATTER=0
        continue
    fi
    if printf '%s' "$line" | grep -qE '^! '; then
        report "HIGH" "Line $LINE_NUM: harness execution (runs at skill load, bypassing agent) — $line"
    fi
    if [ "$IN_FRONTMATTER" -eq 1 ] && printf '%s' "$line" | grep -qiE '^\s*hooks?\s*:'; then
        report "HIGH" "Line $LINE_NUM: YAML frontmatter contains hooks directive — $line"
    fi
done < "$SKILL_FILE"

# --- Everything else: the shared, tested agent-guard policy engine ---
if ! command -v guard >/dev/null 2>&1; then
    report "HIGH" "'guard' not found on PATH — cannot run content-pattern checks (fail-closed). Install with: pipx install \"agentguard[yaml] @ git+https://github.com/voltagebots/agent-guard.git\" (then: pipx inject agentguard pyyaml)."
else
    file_content=$(cat "$SKILL_FILE")
    call_json=$(jq -nc --arg content "$file_content" '{tool:"write",args:{content:$content}}')
    verdict_json=$(printf '%s' "$call_json" | guard check --policy "$POLICY" --json 2>&1)
    guard_exit=$?

    if [ "$guard_exit" -eq 1 ]; then
        report "HIGH" "guard crashed evaluating this file (fail-closed). Raw output: ${verdict_json}"
    else
        decision=$(printf '%s' "$verdict_json" | jq -r '.decision // empty' 2>/dev/null)
        reason=$(printf '%s' "$verdict_json" | jq -r '.reason // empty' 2>/dev/null)
        if [ "$decision" = "deny" ]; then
            report "HIGH" "$reason"
        elif [ "$decision" = "require_human" ]; then
            report "MEDIUM" "$reason"
        elif [ "$decision" = "allow" ] && [ -n "$reason" ] && [ "$reason" != "no rule matched; policy default" ]; then
            report "MEDIUM" "$reason"
        fi
    fi
fi

printf "\n${BOLD}--- Summary ---${RESET}\n"
printf "${RED}HIGH:   %d${RESET}\n" "$HIGH_COUNT"
printf "${YELLOW}MEDIUM: %d${RESET}\n" "$MEDIUM_COUNT"
printf "\n"

if [ "$HIGH_COUNT" -gt 0 ]; then
    printf "${RED}${BOLD}BLOCKED: %d high-risk finding(s). Do not install this skill.${RESET}\n" "$HIGH_COUNT"
    exit 1
fi

if [ "$MEDIUM_COUNT" -gt 0 ]; then
    printf "${YELLOW}${BOLD}WARNING: %d medium-risk finding(s). Review before installing.${RESET}\n" "$MEDIUM_COUNT"
    exit 0
fi

printf "${GREEN}${BOLD}OK: No security risks detected.${RESET}\n"
exit 0

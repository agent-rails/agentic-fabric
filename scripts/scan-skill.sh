#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0

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

report_finding() {
    local severity="$1"
    local description="$2"
    local line_num="$3"
    local line_content="$4"

    case "$severity" in
        HIGH)
            HIGH_COUNT=$((HIGH_COUNT + 1))
            printf "${RED}[HIGH]${RESET} %s\n" "$description"
            ;;
        MEDIUM)
            MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
            printf "${YELLOW}[MEDIUM]${RESET} %s\n" "$description"
            ;;
        LOW)
            LOW_COUNT=$((LOW_COUNT + 1))
            printf "${CYAN}[LOW]${RESET} %s\n" "$description"
            ;;
    esac
    printf "  Line %d: %s\n\n" "$line_num" "$line_content"
}

LINE_NUM=0
IN_FRONTMATTER=0
FRONTMATTER_STARTED=0

while IFS= read -r line || [ -n "$line" ]; do
    LINE_NUM=$((LINE_NUM + 1))

    if [ "$LINE_NUM" -eq 1 ] && printf '%s' "$line" | grep -qE '^\-\-\-\s*$'; then
        IN_FRONTMATTER=1
        FRONTMATTER_STARTED=1
        continue
    fi

    if [ "$IN_FRONTMATTER" -eq 1 ] && printf '%s' "$line" | grep -qE '^\-\-\-\s*$'; then
        IN_FRONTMATTER=0
        continue
    fi

    if printf '%s' "$line" | grep -qE '^! '; then
        report_finding "HIGH" "Harness execution (runs at skill load bypassing agent)" "$LINE_NUM" "$line"
    fi

    if [ "$IN_FRONTMATTER" -eq 1 ] && printf '%s' "$line" | grep -qiE '^\s*hooks?\s*:'; then
        report_finding "HIGH" "YAML frontmatter contains hooks directive" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qiE '(~/\.claude/CLAUDE\.md|CLAUDE\.md)' ; then
        report_finding "HIGH" "Reference to CLAUDE.md (memory poisoning risk)" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qiE '(~/\.ssh/|credentials|tokens|secrets)' ; then
        report_finding "HIGH" "Reference to sensitive paths/credentials" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE '[A-Za-z0-9+/]{50,}={0,2}' ; then
        report_finding "HIGH" "Possible base64 encoded string detected" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE '(curl|wget)\s+.*\|\s*(sh|bash)' ; then
        report_finding "HIGH" "Remote code execution: pipe to shell" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE '\beval\s*\(' ; then
        report_finding "HIGH" "eval() call detected" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE '\bexec\s*\(' ; then
        report_finding "HIGH" "exec() call detected" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE '\bln\s+-s\b' ; then
        report_finding "HIGH" "Symlink creation detected" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE 'git\s+reset\s+--hard' ; then
        report_finding "MEDIUM" "Destructive git operation: reset --hard" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE 'rm\s+-(rf|fr|f)\b' ; then
        report_finding "MEDIUM" "Destructive file operation: rm -rf/-f" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qiE '\.env\b' ; then
        report_finding "MEDIUM" "Reference to .env file" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE '\b(chmod|chown)\b' ; then
        report_finding "MEDIUM" "Permission modification command" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE '\b(curl|wget|fetch)\b' && ! printf '%s' "$line" | grep -qE '\|\s*(sh|bash)'; then
        report_finding "MEDIUM" "Network call detected" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE '(>>?\s|tee\s|write|Write|cat\s*>)' ; then
        report_finding "LOW" "File write operation" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE '\bgit\s+(add|commit|push|pull|merge|checkout|branch)\b' && ! printf '%s' "$line" | grep -qE 'reset\s+--hard'; then
        report_finding "LOW" "Git operation" "$LINE_NUM" "$line"
    fi

    if printf '%s' "$line" | grep -qE '\bmkdir\b' ; then
        report_finding "LOW" "Directory creation" "$LINE_NUM" "$line"
    fi

done < "$SKILL_FILE"

printf "${BOLD}--- Summary ---${RESET}\n"
printf "${RED}HIGH:   %d${RESET}\n" "$HIGH_COUNT"
printf "${YELLOW}MEDIUM: %d${RESET}\n" "$MEDIUM_COUNT"
printf "${CYAN}LOW:    %d${RESET}\n" "$LOW_COUNT"
printf "\n"

if [ "$HIGH_COUNT" -gt 0 ]; then
    printf "${RED}${BOLD}BLOCKED: %d high-risk pattern(s) found. Do not install this skill.${RESET}\n" "$HIGH_COUNT"
    exit 1
fi

if [ "$MEDIUM_COUNT" -gt 0 ]; then
    printf "${YELLOW}${BOLD}WARNING: %d medium-risk pattern(s) found. Review before installing.${RESET}\n" "$MEDIUM_COUNT"
    exit 0
fi

printf "${GREEN}${BOLD}OK: No security risks detected.${RESET}\n"
exit 0

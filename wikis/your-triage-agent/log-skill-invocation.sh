#!/usr/bin/env bash
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SKILL=$(jq -r '.tool_input.skill // empty')
[ -n "$SKILL" ] && echo "{\"timestamp\":\"$TS\",\"skill\":\"$SKILL\"}" >> ~/your-triage-agent/wiki/recurring/.invocations.jsonl
exit 0

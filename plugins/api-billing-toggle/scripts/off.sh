#!/usr/bin/env bash
# Turn OFF API-key billing in ~/.claude/settings.json by removing
# apiKeyHelper and env.ANTHROPIC_API_KEY. Leaves other env vars intact.
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"

if [[ ! -f "$SETTINGS" ]]; then
  echo "ERROR: $SETTINGS does not exist." >&2
  exit 1
fi

TMP="$(mktemp)"
jq '
  del(.apiKeyHelper) |
  if (.env | type) == "object" then
    .env |= del(.ANTHROPIC_API_KEY) |
    if (.env | length) == 0 then del(.env) else . end
  else . end
' "$SETTINGS" > "$TMP"

mv "$TMP" "$SETTINGS"
chmod 600 "$SETTINGS"
echo "API-key billing: OFF. Restart Claude Code to take effect."

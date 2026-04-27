#!/usr/bin/env bash
# Turn ON API-key billing in ~/.claude/settings.json by injecting the key
# stored in macOS Keychain (service: claude-code-api-key, account: anthropic).
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
SERVICE="claude-code-api-key"
ACCOUNT="anthropic"

if [[ ! -f "$SETTINGS" ]]; then
  echo "ERROR: $SETTINGS does not exist." >&2
  exit 1
fi

KEY="$(security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w 2>/dev/null || true)"

if [[ -z "$KEY" ]]; then
  echo "No API key found in Keychain (service=$SERVICE, account=$ACCOUNT)."
  echo "Store one with:"
  echo "  security add-generic-password -s '$SERVICE' -a '$ACCOUNT' -w 'sk-ant-...' -U"
  exit 1
fi

TMP="$(mktemp)"
jq --arg k "$KEY" '
  .apiKeyHelper = ("echo " + $k) |
  .env = ((.env // {}) + {ANTHROPIC_API_KEY: $k})
' "$SETTINGS" > "$TMP"

mv "$TMP" "$SETTINGS"
chmod 600 "$SETTINGS"
echo "API-key billing: ON. Restart Claude Code to take effect."

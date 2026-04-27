#!/usr/bin/env bash
# Turn ON API-key billing in ~/.claude/settings.json by injecting the key
# stored in macOS Keychain (service: claude-code-api-key, account: anthropic).
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
SERVICE="claude-code-api-key"
ACCOUNT="anthropic"

if [[ ! -f "$SETTINGS" ]]; then
  echo "✗ ERROR: $SETTINGS does not exist." >&2
  exit 1
fi

KEY="$(security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w 2>/dev/null || true)"

if [[ -z "$KEY" ]]; then
  cat >&2 <<EOF
✗ No API key found in macOS Keychain
  (service=$SERVICE, account=$ACCOUNT)

To store a key, run:

  security add-generic-password \\
    -s '$SERVICE' \\
    -a '$ACCOUNT' \\
    -w 'sk-ant-api03-...' \\
    -U

Then run this script again. The settings.json was NOT modified.
EOF
  exit 1
fi

TMP="$(mktemp)"
jq --arg k "$KEY" '
  .apiKeyHelper = ("echo " + $k) |
  .env = ((.env // {}) + {ANTHROPIC_API_KEY: $k})
' "$SETTINGS" > "$TMP"

mv "$TMP" "$SETTINGS"
chmod 600 "$SETTINGS"

cat <<EOF
✓ API-key billing is now ON

What changed in ~/.claude/settings.json:
  • apiKeyHelper       → echo <your-key>
  • env.ANTHROPIC_API_KEY → <your-key>
  (key pulled from macOS Keychain — never written to any other file)

What to do next:
  1. Quit Claude Code completely (Cmd-Q — closing the window is not enough)
  2. Reopen Claude Code
  3. Future Claude Code sessions will bill against the API key (Console)
     instead of your Pro/Max subscription

Verify (in a new terminal):
  jq '{apiKeyHelper, env}' ~/.claude/settings.json
  → both fields should be present and non-null
EOF

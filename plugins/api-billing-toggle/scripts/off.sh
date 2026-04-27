#!/usr/bin/env bash
# Turn OFF API-key billing in ~/.claude/settings.json by removing
# apiKeyHelper and env.ANTHROPIC_API_KEY. Leaves other env vars intact.
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"

if [[ ! -f "$SETTINGS" ]]; then
  echo "✗ ERROR: $SETTINGS does not exist." >&2
  exit 1
fi

# Detect prior state so we can tell the user what actually changed.
HAD_HELPER=$(jq 'has("apiKeyHelper")' "$SETTINGS")
HAD_ENV_KEY=$(jq '(.env // {}) | has("ANTHROPIC_API_KEY")' "$SETTINGS")

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

if [[ "$HAD_HELPER" == "false" && "$HAD_ENV_KEY" == "false" ]]; then
  cat <<EOF
✓ API-key billing was already OFF (nothing to change)

Your ~/.claude/settings.json has no apiKeyHelper or ANTHROPIC_API_KEY,
so Claude Code will use your Pro/Max subscription for billing.

If Claude Code is showing a 401 / "Invalid authentication credentials"
error, run /login inside Claude Code to re-authenticate.
EOF
else
  cat <<EOF
✓ API-key billing is now OFF

What changed in ~/.claude/settings.json:
EOF
  [[ "$HAD_HELPER" == "true" ]]   && echo "  • Removed apiKeyHelper"
  [[ "$HAD_ENV_KEY" == "true" ]]  && echo "  • Removed env.ANTHROPIC_API_KEY"
  cat <<EOF

Future Claude Code sessions will use your Pro/Max subscription for billing.
Your API key is still safe in macOS Keychain — run on.sh to switch back.

What to do next:
  1. Quit Claude Code completely (Cmd-Q — closing the window is not enough)
  2. Reopen Claude Code
  3. If you see a 401 / "Invalid authentication credentials" error,
     run /login to authenticate with your Pro/Max account

Verify (in a new terminal):
  jq '{apiKeyHelper, env}' ~/.claude/settings.json
  → apiKeyHelper should be null/absent
EOF
fi

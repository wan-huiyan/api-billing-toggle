---
name: api-billing-toggle
description: Use when the user wants to switch Claude Code billing between API-key (Console) and subscription (Pro/Max). Toggles `apiKeyHelper` and `env.ANTHROPIC_API_KEY` in ~/.claude/settings.json on/off. The key itself lives in macOS Keychain (service=claude-code-api-key, account=anthropic), never in plaintext on disk. TRIGGER PHRASES (any of these should activate this skill): "turn API billing on", "turn API billing off", "enable API billing", "disable API billing", "switch to API key billing", "switch to API key", "switch to subscription", "switch to Claude Pro", "switch to Claude Max", "use my Anthropic API key", "use my API key for Claude Code", "stop using my API key", "billing on", "billing off", "api on", "api off", "put API key back", "restore API key billing", "remove API key billing", "bring back the API key", "use Pro account", "use subscription account", "Console billing on", "Console billing off". Also triggers on "/api-billing-on" or "/api-billing-off" if the user types those commands.
---

# API Billing Toggle

Switches `~/.claude/settings.json` between two states:

- **ON** — `apiKeyHelper` and `env.ANTHROPIC_API_KEY` are populated from macOS Keychain. Claude Code bills against the Anthropic API key (Console).
- **OFF** — both fields are removed. Claude Code falls back to the logged-in OAuth account (Pro/Max subscription).

The key is stored in macOS Keychain, not in `settings.json`.

## How to use

**Turn ON:**
```bash
~/.claude/skills/api-billing-toggle/scripts/on.sh
```

**Turn OFF:**
```bash
~/.claude/skills/api-billing-toggle/scripts/off.sh
```

Restart Claude Code after either command for the change to take effect.

## One-time setup: store the key in Keychain

Before the first `on.sh`, store your API key:
```bash
security add-generic-password \
  -s 'claude-code-api-key' \
  -a 'anthropic' \
  -w 'sk-ant-api03-...' \
  -U
```

The `-U` flag updates the entry if it already exists. macOS will prompt for your login password the first time `on.sh` reads it; click "Always Allow" to skip future prompts.

## Rotate or replace the key

Re-run the `security add-generic-password ... -U` command above with the new key. Then run `on.sh` to push the new key into settings.json.

## Verify which mode is active

```bash
jq '{apiKeyHelper, env}' ~/.claude/settings.json
```

If both are `null` / absent, you're on subscription billing.

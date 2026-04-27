# api-billing-toggle

Toggle Claude Code between Anthropic API-key billing (Console) and Pro/Max subscription — without ever putting your API key in plaintext.

[![GitHub release](https://img.shields.io/github/v/release/wan-huiyan/api-billing-toggle)](https://github.com/wan-huiyan/api-billing-toggle/releases)
[![license](https://img.shields.io/github/license/wan-huiyan/api-billing-toggle)](LICENSE)
[![last commit](https://img.shields.io/github/last-commit/wan-huiyan/api-billing-toggle)](https://github.com/wan-huiyan/api-billing-toggle/commits)
[![Claude Code](https://img.shields.io/badge/Claude_Code-skill-orange)](https://claude.com/claude-code)
[![macOS](https://img.shields.io/badge/macOS-required-blue)](#requirements)

## The problem

Claude Code reads two fields from `~/.claude/settings.json` to bill against an Anthropic API key:

- `apiKeyHelper` — a shell command that prints the key
- `env.ANTHROPIC_API_KEY` — the key as an environment variable

The path of least resistance is to paste the key directly into both fields. That puts the key in plaintext on disk, in a file that's easy to grep, easy to leak, and frequently visible to AI agents reading their own config. If the key ever ends up in a git repo, a screenshot, or a model's context window, you have to rotate.

The right fix is "store the key once in macOS Keychain, then flip a switch when you want to use it." That's this skill.

## Quick start

```
You: turn API billing on
Claude: [runs on.sh, pulls the key from Keychain, writes both fields]
        API-key billing: ON. Restart Claude Code to take effect.

You: switch back to subscription
Claude: [runs off.sh, removes both fields]
        API-key billing: OFF. Restart Claude Code to take effect.
```

Or use the slash commands directly: `/api-billing-on` and `/api-billing-off`.

## Installation

**Claude Code (plugin install):**

```bash
/plugin marketplace add wan-huiyan/api-billing-toggle
/plugin install api-billing-toggle@wan-huiyan-api-billing-toggle
```

**Claude Code (git clone):**

```bash
git clone https://github.com/wan-huiyan/api-billing-toggle.git \
  ~/.claude/skills/api-billing-toggle
```

## One-time setup

Store your Anthropic API key in macOS Keychain:

```bash
security add-generic-password \
  -s 'claude-code-api-key' \
  -a 'anthropic' \
  -w 'sk-ant-api03-...' \
  -U
```

The `-U` flag updates an existing entry, so you can run this again any time you rotate the key. macOS will prompt for your login password the first time the on-script reads it; click "Always Allow" to skip future prompts.

## How it works

| Step | What happens |
|---|---|
| `on.sh` reads Keychain | `security find-generic-password -s 'claude-code-api-key' -a 'anthropic' -w` |
| Writes settings.json | `jq` injects `apiKeyHelper: "echo $KEY"` and `env.ANTHROPIC_API_KEY: $KEY` |
| `off.sh` strips both | `jq 'del(.apiKeyHelper) \| .env \|= del(.ANTHROPIC_API_KEY)'` (also removes `env` if it becomes empty) |
| Claude Code restart | The settings change applies on next launch |

The key is never written to a regular file. It lives in Keychain (encrypted, gated by your login password) and only touches `settings.json` when you flip on, never when off.

## Optional: slash commands

The skill ships with a `SKILL.md` whose description includes ~25 trigger phrases (including "switch to API key billing", "switch to Pro", "Console billing on", etc.) so Claude can pick it up from natural language. For deterministic invocation, add these slash commands to `~/.claude/commands/`:

**`~/.claude/commands/api-billing-on.md`:**

```markdown
---
description: Turn ON Anthropic API-key billing for Claude Code
---

Run `~/.claude/skills/api-billing-toggle/scripts/on.sh` and report the result.
Remind the user to restart Claude Code afterwards.
```

**`~/.claude/commands/api-billing-off.md`:**

```markdown
---
description: Turn OFF Anthropic API-key billing for Claude Code
---

Run `~/.claude/skills/api-billing-toggle/scripts/off.sh` and report the result.
Remind the user to restart Claude Code afterwards.
```

## Verifying current state

```bash
jq 'has("apiKeyHelper"), (.env | (.ANTHROPIC_API_KEY != null))' ~/.claude/settings.json
```

Both `false` → subscription billing. Both `true` → API-key billing.

## Troubleshooting

### `Please run /login · API Error: 401 Invalid authentication credentials` after running `off.sh`

**This is the expected next step, not an error.** When `off.sh` removes `apiKeyHelper` and `env.ANTHROPIC_API_KEY` from `settings.json`, there is no auth left for Claude Code to use. The next prompt 401s and Claude Code's own handler asks you to `/login` — which is exactly what you want to do to authenticate with your Pro/Max subscription.

**Just run `/login` and you're done.** No need to re-run the skill.

The flow looks like this:

```
You:    [run off.sh in terminal, quit Cmd-Q, reopen Claude Code]
You:    switch to subscription
Claude: Please run /login · API Error: 401 …       ← expected
You:    /login
Claude: Login successful                            ← now on Pro/Max
```

### Same error but you didn't intend to switch

If the 401 appears unexpectedly (e.g. after rotating your Anthropic API key in the Console without updating Keychain), the dead key is still in `settings.json`. Two ways to fix:

```bash
# Switch to subscription:
~/.claude/skills/api-billing-toggle/scripts/off.sh
# then /login inside Claude Code

# Stay on API billing with the new key:
security add-generic-password -s 'claude-code-api-key' -a 'anthropic' \
  -w 'sk-ant-api03-NEW-KEY-HERE' -U
~/.claude/skills/api-billing-toggle/scripts/on.sh
```

### Restarted Claude Code, still seeing the old billing mode

Closing the window isn't enough on macOS — Claude Code keeps running in the background. Quit with **Cmd-Q** (or `pkill -f "Claude Code"` from terminal) and relaunch.

### `No API key found in macOS Keychain`

The on script's first run on a new machine will print this. Store the key as shown in [One-time setup](#one-time-setup), then re-run `on.sh`. The script does not modify `settings.json` when the key is missing — safe to retry.

## Requirements

- **macOS** (the Keychain integration is macOS-only — `security` CLI)
- **`jq`** (usually pre-installed on macOS; `brew install jq` otherwise)
- **Claude Code** (any recent version)

## Limitations

- macOS only. Linux/Windows users would need to adapt to `pass`, `secret-tool`, or DPAPI.
- The `apiKeyHelper` field stores the key as `echo <key>`, which means a memory dump of Claude Code while running could expose the key. This is the same exposure as the official setup — Keychain protects the at-rest copy, not the running process.
- Restart required after toggling. The settings change is read at launch, not live.
- Doesn't manage multiple keys. The Keychain entry is single-keyed. If you have multiple Anthropic accounts, change the `SERVICE` constant in the scripts.

## Why this design

| Alternative | Why not |
|---|---|
| `~/.claude/.api-key` file (gitignored) | Still plaintext; one `cat` away from leaking |
| Environment variable in `.zshrc` | Same problem, plus visible to every child process |
| 1Password CLI | Heavier dependency; overkill for one key |
| Just leave it in settings.json | The default. Easy to leak via screenshots, copy-paste, or AI context windows |

macOS Keychain is the cheapest way to get encryption-at-rest with no extra dependencies.

## Security notes

- If you've ever pasted your API key into `settings.json`, **rotate it** at https://console.anthropic.com/settings/keys before installing this skill. Then store the new key in Keychain.
- The scripts `chmod 600` settings.json after writing. If your existing settings.json has more permissive perms, this skill tightens them.
- Keychain is gated by your macOS login password. If your login password is weak, fix that first.

## Version history

- **v1.0.2** (2026-04-27) — Corrected the framing of the post-`off.sh` 401: it's the expected next step (Claude Code asking for `/login`), not an error. Updated `off.sh` output and README troubleshooting to make this clear. Tested with real-world walkthrough.
- **v1.0.1** (2026-04-27) — Friendlier script output: explicit confirmation, list of what changed, next-step instructions, and 401 troubleshooting tip in `off.sh` for already-off case. Added Troubleshooting section to README covering the common "401 after key rotation" scenario.
- **v1.0.0** (2026-04-27) — Initial release. on/off scripts, SKILL.md with natural-language triggers, slash command templates.

## License

MIT — see [LICENSE](LICENSE).

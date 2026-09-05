# AI Monitor

DankMaterialShell widget plugin for monitoring AI subscription usage through
`codexbar`.

## Requirements

- DankMaterialShell
- `codexbar`
- An active Codex login (`codex login`) for Codex usage
- An Antigravity login (`agy`, or sign in to the Antigravity app) for
  Gemini usage
- Logged-in provider CLIs for other providers you want to monitor

The widget currently reads:

```sh
codexbar usage --provider codex --source oauth --format json --pretty --no-color
codexbar usage --provider claude --source cli --format json --pretty --no-color
codexbar usage --provider antigravity --source cli --format json --pretty --no-color
```

The Codex OAuth source reuses the existing Codex login and does not require a
separate AI Monitor sign-in. Codex displays its five-hour window and any
additional weekly limit. Claude keeps its session, weekly, and model-specific
usage sections.

Antigravity covers the Gemini/`antigravity-cli` quota. It shows the Gemini
five-hour and weekly windows, plus the separate Claude/GPT five-hour and weekly
windows that Antigravity meters independently. When Antigravity reports an
offline session, the widget keeps the last successful reading and marks it as
stale instead of blanking the card.

## Install

```sh
sh install.sh
```

If DMS is already running, the installer reloads AI Monitor after copying the
updated files.

Then open DMS Settings -> Plugins, scan if needed, enable **AI Monitor**,
and add it to the DankBar widget list.

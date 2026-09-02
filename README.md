# AI Monitor

DankMaterialShell widget plugin for monitoring AI subscription usage through
`codexbar`.

## Requirements

- DankMaterialShell
- `codexbar`
- An active Codex login (`codex login`) for Codex usage
- Logged-in provider CLIs for other providers you want to monitor

The widget currently reads:

```sh
codexbar usage --provider codex --source oauth --format json --pretty --no-color
codexbar usage --provider claude --source cli --format json --pretty --no-color
```

The Codex OAuth source reuses the existing Codex login and does not require a
separate AI Monitor sign-in. Codex displays its five-hour window and any
additional weekly limit. Claude keeps its session, weekly, and model-specific
usage sections.

## Install

```sh
sh install.sh
```

If DMS is already running, the installer reloads AI Monitor after copying the
updated files.

Then open DMS Settings -> Plugins, scan if needed, enable **AI Monitor**,
and add it to the DankBar widget list.

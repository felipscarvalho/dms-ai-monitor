# AI Monitor

DankMaterialShell widget plugin for monitoring AI subscription usage through
`codexbar`.

## Requirements

- DankMaterialShell
- `codexbar`
- Logged-in provider CLIs for the providers you want to monitor

The widget currently reads:

```sh
codexbar usage --provider codex --source cli --format json --pretty --no-color
codexbar usage --provider claude --source cli --format json --pretty --no-color
```

## Install

```sh
sh install.sh
```

Then open DMS Settings -> Plugins, scan if needed, enable **AI Monitor**,
and add it to the DankBar widget list.

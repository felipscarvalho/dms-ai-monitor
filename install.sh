#!/usr/bin/env sh
set -eu

plugin_id="aiMonitor"
src_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
dest_base="${XDG_CONFIG_HOME:-"$HOME/.config"}/DankMaterialShell/plugins"
dest_dir="${dest_base}/${plugin_id}"

if ! command -v codexbar >/dev/null 2>&1; then
  printf '%s\n' "warning: codexbar was not found in PATH. Install it before enabling the widget." >&2
fi

mkdir -p "$dest_base"
mkdir -p "$dest_dir"
cp "$src_dir/plugin.json" "$dest_dir/plugin.json"
cp "$src_dir/AiMonitorWidget.qml" "$dest_dir/AiMonitorWidget.qml"
mkdir -p "$dest_dir/assets"
cp "$src_dir/assets/openai.svg" "$dest_dir/assets/openai.svg"
cp "$src_dir/assets/anthropic.svg" "$dest_dir/assets/anthropic.svg"

printf 'Installed %s to %s\n' "$plugin_id" "$dest_dir"

plugin_reloaded=false
if command -v qs >/dev/null 2>&1; then
  if qs ipc -p /usr/share/quickshell/dms call plugins reload "$plugin_id" >/dev/null 2>&1 ||
    env -u LD_LIBRARY_PATH qs ipc -p /usr/share/quickshell/dms call plugins reload "$plugin_id" >/dev/null 2>&1; then
    plugin_reloaded=true
  fi
fi

if [ "$plugin_reloaded" = true ]; then
  printf '%s\n' "Reloaded AI Monitor in the running DMS session."
else
  printf '%s\n' "DMS is not running or could not reload the plugin. Run 'dms restart' if an older version is still visible."
fi

printf '%s\n' "Open DMS Settings -> Plugins, scan if needed, enable AI Monitor, then add it to DankBar."

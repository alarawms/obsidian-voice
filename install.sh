#!/bin/bash
# Install Obsidian Voice Capture for the current user.
#   ./install.sh              link the plugin into ~/.config/omarchy/plugins (when run from a checkout elsewhere),
#                              put the `obsidian-voice-capture` CLI on PATH, enable the bar widget
#   ./install.sh --uninstall
#
# The Hyprland keybinding is not added automatically — see README.md for the
# one line to add to ~/.config/hypr/bindings.lua. The CLI works standalone
# regardless (bar widget optional): `obsidian-voice-capture toggle`.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ID=alarawms.obsidian-voice
PLUGIN=$HOME/.config/omarchy/plugins/$ID
BIN=$HOME/.local/bin
MODE=${1:-}

if [[ $MODE == --uninstall ]]; then
  omarchy-plugin-disable "$ID" >/dev/null 2>&1 || true
  rm -f "$BIN/obsidian-voice-capture"
  [[ -L $PLUGIN ]] && rm -f "$PLUGIN"
  echo "uninstalled (config in ~/.config/obsidian-voice and any notes already filed in your vault were left alone)"
  echo "If the plugin was added with 'omarchy plugin add', also run: omarchy plugin remove $ID"
  echo "Remove the SUPER+SHIFT+V binding from ~/.config/hypr/bindings.lua if you added it."
  exit 0
fi

missing=()
for c in jq pw-record voxtype; do
  command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
if ((${#missing[@]})); then
  echo "error: missing commands: ${missing[*]} (jq, pipewire, and Omarchy's voxtype dictation engine are required)" >&2
  [[ " ${missing[*]} " == *" voxtype "* ]] && echo "note: install voxtype with 'omarchy-voxtype-install' or from Omarchy's Settings." >&2
  exit 1
fi

mkdir -p "$BIN" "$(dirname "$PLUGIN")"
ln -sfn "$HERE/bin/obsidian-voice-capture" "$BIN/obsidian-voice-capture"
chmod +x "$HERE/bin/obsidian-voice-capture"

# A checkout somewhere else is linked in; a checkout that already lives in the
# plugins dir (omarchy plugin add) is used in place.
if [[ $HERE != "$PLUGIN" ]]; then
  if [[ -e $PLUGIN && ! -L $PLUGIN ]]; then
    echo "error: $PLUGIN exists and is not a symlink; remove it first (omarchy plugin remove $ID)" >&2
    exit 1
  fi
  ln -sfn "$HERE" "$PLUGIN"
fi

case ":$PATH:" in *":$BIN:"*) ;; *) echo "note: $BIN is not on your PATH; the Hyprland keybinding runs 'obsidian-voice-capture' from there." >&2 ;; esac

omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy-plugin-enable "$ID" --section right >/dev/null 2>&1 || omarchy-plugin-enable "$ID" >/dev/null 2>&1 || true

echo "installed: the mic icon is in the bar."
echo "Set \"vault\" in ~/.config/obsidian-voice/config.json to your Obsidian vault path (required — created empty on first run)."
echo "Add the keybinding from README.md to ~/.config/hypr/bindings.lua, then 'hyprctl reload'."

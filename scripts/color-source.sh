#!/usr/bin/env bash
# ~/.config/scripts/color-source.sh [theme|wallpaper|toggle|status]
#
# Chooses where the colors come from:
#   theme      -> the palette of the active theme (themes/<name>/palette.conf)
#   wallpaper  -> colors extracted from the current wallpaper with pywal
# Bound to a keybind (SUPER+SHIFT+C) and the theme picker. Survives reboots.

set -uo pipefail

STATE="$HOME/.local/state/rice"
FILE="$STATE/color-source"
mkdir -p "$STATE"

CUR="$(cat "$FILE" 2>/dev/null || echo theme)"
case "${1:-status}" in
    theme|wallpaper)
        echo "$1" > "$FILE"
        ;;
    toggle)
        if [ "$CUR" = theme ]; then echo wallpaper > "$FILE"; else echo theme > "$FILE"; fi
        ;;
    status)
        echo "$CUR"
        exit 0
        ;;
    *)
        echo "Usage: color-source.sh [theme|wallpaper|toggle|status]" >&2
        exit 1
        ;;
esac

if [ "$(cat "$FILE")" = wallpaper ] && ! command -v wal >/dev/null; then
    notify-send -a Colors "Install python-pywal for wallpaper colors" 2>/dev/null || true
fi

"$HOME/.config/scripts/colors-refresh.sh"

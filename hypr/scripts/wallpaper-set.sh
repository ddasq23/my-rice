#!/usr/bin/env bash
# ~/.config/hypr/scripts/wallpaper-set.sh <image> [--no-refresh]
#
# Sets the wallpaper live through hyprpaper IPC, remembers it across reboots
# (hypr/hyprpaper.conf + ~/.local/state/rice/wallpaper), and — when the color
# source is "wallpaper" — regenerates the colors from the new image.
#
# Used by theme-switch.sh (with --no-refresh, it refreshes colors itself) and
# by you directly:  ~/.config/hypr/scripts/wallpaper-set.sh ~/Pictures/x.png

set -uo pipefail

CFG="$HOME/.config"
STATE="$HOME/.local/state/rice"
IMG="${1:-}"
REFRESH=1
[ "${2:-}" = "--no-refresh" ] && REFRESH=0

if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "Usage: wallpaper-set.sh <image> [--no-refresh]" >&2
    exit 1
fi
IMG="$(readlink -f "$IMG")"
mkdir -p "$STATE"
echo "$IMG" > "$STATE/wallpaper"

# Persist for next login (hyprpaper reads this file at startup).
cat > "$CFG/hypr/hyprpaper.conf" <<EOF
# ~/.config/hypr/hyprpaper.conf
# Rewritten by hypr/scripts/wallpaper-set.sh — the current wallpaper survives reboots.
preload = $IMG
wallpaper = ,$IMG
splash = false
EOF

# Live swap, no restart.
if command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; then
    hyprctl hyprpaper preload "$IMG" >/dev/null 2>&1 || true
    hyprctl hyprpaper wallpaper ",$IMG" >/dev/null 2>&1 || true
    hyprctl hyprpaper unload unused >/dev/null 2>&1 || true
fi

if [ "$REFRESH" = 1 ]; then
    "$CFG/scripts/colors-refresh.sh"
fi

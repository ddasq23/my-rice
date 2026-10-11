#!/usr/bin/env bash
# ~/.config/scripts/theme-switch.sh <theme-name>
#        theme-switch.sh --list
#
# Applies a complete theme in one go:
#   palette (themes/<name>/palette.conf) -> Hyprland borders + cursor, Waybar,
#   wofi, Eww, kitty, dunst, fuzzel (app menu), GTK 3/4, Qt (qt5ct), and the
#   wallpaper (wallpapers/<name>.png). Everything is rendered by
#   theme-render.py, then applied live by colors-refresh.sh.
#
# If the color source is "wallpaper" (see color-source.sh), the new wallpaper
# drives the colors instead of the theme palette.
#
# Add your own theme: copy themes/nord to themes/my-theme, edit palette.conf,
# and run `theme-switch.sh my-theme`. See README → Themes.

set -uo pipefail

CFG="$HOME/.config"
THEMES_DIR="$CFG/themes"

if [ "${1:-}" = "--list" ]; then
    for d in "$THEMES_DIR"/*/; do
        [ -f "$d/palette.conf" ] && basename "$d"
    done
    exit 0
fi

THEME="${1:-}"
PAL="$THEMES_DIR/$THEME/palette.conf"
if [ -z "$THEME" ] || [ ! -f "$PAL" ]; then
    echo "Usage: theme-switch.sh <theme-name>   (or --list)" >&2
    echo "Available: $("$0" --list | tr '\n' ' ')" >&2
    exit 1
fi

WALL_NAME="$(sed -n 's/^wallpaper *= *//p' "$PAL" | head -n1)"
WALL="$CFG/wallpapers/$WALL_NAME"

echo "$THEME" > "$CFG/current_theme"

# Wallpaper first (persists + live swap), colors refreshed once at the end.
if [ -f "$WALL" ]; then
    "$CFG/hypr/scripts/wallpaper-set.sh" "$WALL" --no-refresh || true
fi

"$CFG/scripts/colors-refresh.sh"

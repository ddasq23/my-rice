#!/usr/bin/env bash
# ~/.config/scripts/theme-switch.sh <theme-name>
#
# Swaps every color file for the chosen theme and applies changes live:
#   - Hyprland border colors: hyprctl keyword (instant, no reload/flicker)
#   - Wallpaper: hyprpaper IPC (instant, no compositor restart)
#   - Waybar/Wofi: overwrite colors.css (GTK CSS re-reads on next open;
#     waybar gets a SIGUSR2 which most builds treat as a live style reload)
#   - Eww: `eww reload` recompiles scss/yuck in place, no daemon restart
#   - Dunst: quick respawn (near-instant, no visible gap in practice)
#   - Kitty: existing windows keep old colors until reopened (kitty doesn't
#     support live theme swap without `kitty @` remote control enabled)

set -euo pipefail

CFG="$HOME/.config"
THEME="${1:-}"
THEMES_DIR="$CFG/themes"

if [ -z "$THEME" ] || [ ! -d "$THEMES_DIR/$THEME" ]; then
    echo "Usage: theme-switch.sh <theme-name>"
    echo "Available: $(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f ' 2>/dev/null)"
    exit 1
fi

SRC="$THEMES_DIR/$THEME"

# --- Waybar + Wofi (shared palette) ---
cp "$SRC/colors.css" "$CFG/waybar/colors.css"
cp "$SRC/colors.css" "$CFG/wofi/colors.css"

# --- Eww ---
cp "$SRC/eww-colors.scss" "$CFG/eww/colors.scss"

# --- Kitty ---
cp "$SRC/kitty-theme.conf" "$CFG/kitty/theme.conf"

# --- Hyprland border colors ---
cp "$SRC/hypr-colors.conf" "$CFG/hypr/colors.conf"

# --- Dunst ---
cp "$SRC/dunstrc" "$CFG/dunst/dunstrc"

# --- Remember selection for the sidebar/picker highlight ---
echo "$THEME" > "$CFG/current_theme"

# =========================== apply live, no lag ===========================

# Hyprland: read the new colors.conf values and push them straight into the
# running compositor — instant, no reload/flicker.
# NOTE: hypr-colors.conf is a Hyprland file ($var = rgba(...)), not a shell
# file — sourcing it would be a syntax error, so parse the three values out.
border_file="$SRC/hypr-colors.conf"
borderActive1="$(sed -n 's/^[$]borderActive1 *= *//p' "$border_file")"
borderActive2="$(sed -n 's/^[$]borderActive2 *= *//p' "$border_file")"
borderInactive="$(sed -n 's/^[$]borderInactive *= *//p' "$border_file")"
if [ -n "$borderActive1" ] && command -v hyprctl >/dev/null; then
    hyprctl --batch "keyword general:col.active_border $borderActive1 $borderActive2 45deg ; keyword general:col.inactive_border $borderInactive" >/dev/null || true
fi

# Wallpaper via hyprpaper IPC — instant swap, no compositor restart.
WALL="$CFG/wallpapers/$THEME.png"
if [ -f "$WALL" ] && command -v hyprctl >/dev/null; then
    hyprctl hyprpaper preload "$WALL" >/dev/null 2>&1 || true
    hyprctl hyprpaper wallpaper ",$WALL" >/dev/null 2>&1 || true
    hyprctl hyprpaper unload unused >/dev/null 2>&1 || true
fi

# Waybar: SIGUSR2 triggers a style reload on recent builds without a full
# relaunch; fall back to a quick respawn if that does nothing visible.
if pgrep -x waybar >/dev/null; then
    pkill -SIGUSR2 waybar 2>/dev/null || { pkill waybar; setsid waybar >/dev/null 2>&1 & }
fi

# Eww: reload recompiles scss/yuck in place without restarting the daemon.
if pgrep -x eww >/dev/null; then
    eww reload >/dev/null 2>&1 || true
fi

# Dunst: no live-reload signal, so a fast respawn is the only option —
# effectively instant since it's just a config re-read.
pkill dunst 2>/dev/null || true
setsid dunst >/dev/null 2>&1 &

notify-send -a "Theme" "Switched to $THEME" 2>/dev/null || true

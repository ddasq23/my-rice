#!/usr/bin/env bash
# ~/.config/scripts/theme-picker.sh
# Super+T — pick a theme from a wofi menu, applied instantly.

THEMES_DIR="$HOME/.config/themes"

CHOICE=$(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
    | sort | wofi --dmenu --prompt "Theme" --width 300 --height 250)

[ -n "$CHOICE" ] && "$HOME/.config/scripts/theme-switch.sh" "$CHOICE"

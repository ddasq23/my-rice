#!/usr/bin/env bash
# ~/.config/scripts/theme-picker.sh
# Super+T — pick a theme from a wofi menu, applied instantly.

THEMES_DIR="$HOME/.config/themes"

CHOICE=$(ls "$THEMES_DIR" | wofi --dmenu --prompt "Theme" --width 300 --height 250)

[ -n "$CHOICE" ] && "$HOME/.config/scripts/theme-switch.sh" "$CHOICE"

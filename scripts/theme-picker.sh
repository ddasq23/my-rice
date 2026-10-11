#!/usr/bin/env bash
# ~/.config/scripts/theme-picker.sh
# SUPER+T — pick a theme (or toggle the color source) from a fuzzel menu.

CFG="$HOME/.config"
MODE="$(cat "$HOME/.local/state/rice/color-source" 2>/dev/null || echo theme)"

CHOICE="$({
    echo "⇄ Colors from: $( [ "$MODE" = wallpaper ] && echo 'wallpaper' || echo 'theme') (toggle)"
    "$CFG/scripts/theme-switch.sh" --list | sort
} | fuzzel --dmenu --prompt "Theme ❯ " --lines 10 --width 40)"

case "$CHOICE" in
    "")                 exit 0 ;;
    "⇄ Colors from:"*)  "$CFG/scripts/color-source.sh" toggle ;;
    *)                  "$CFG/scripts/theme-switch.sh" "$CHOICE" ;;
esac

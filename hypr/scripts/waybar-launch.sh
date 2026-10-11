#!/usr/bin/env bash
# ~/.config/hypr/scripts/waybar-launch.sh
# Starts (or restarts) Waybar with the right config for the current mode:
#   normal      -> waybar/config.jsonc
#   performance -> waybar/config-performance.jsonc (no cpu/memory polling)
# Used by exec-once at login and by performance-mode.sh when toggling.

STATE="$HOME/.local/state/rice/performance"
CFG_DIR="$HOME/.config/waybar"

if [ "$(cat "$STATE" 2>/dev/null)" = "on" ]; then
    CONF="$CFG_DIR/config-performance.jsonc"
else
    CONF="$CFG_DIR/config.jsonc"
fi

pkill -x waybar 2>/dev/null
# Wait briefly for the old bar to exit so the new one doesn't clash.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x waybar >/dev/null || break
    sleep 0.05
done

setsid waybar -c "$CONF" -s "$CFG_DIR/style.css" >/dev/null 2>&1 &

#!/usr/bin/env bash
# ~/.config/hypr/scripts/performance-mode.sh
#
# Performance Mode toggle (Feature 1).
#
#   performance-mode.sh toggle        flip ON/OFF (keybind SUPER+SHIFT+P, Waybar button)
#   performance-mode.sh on|off        set explicitly
#   performance-mode.sh reapply       re-apply the saved state (used at login and
#                                     after `hyprctl reload`, which wipes keywords)
#   performance-mode.sh status        print "on" or "off"
#   performance-mode.sh status-json   JSON for the Waybar custom module
#
# ON  : animations, blur, shadows, transparency, rounded corners and gaps are
#       switched off with `hyprctl --batch keyword` (no reload, instant), the
#       Waybar config is swapped for the lighter one, and the power profile is
#       set to "performance" via power-profiles-daemon (no root needed).
# OFF : the values come back from hypr/user-settings.conf and the active
#       animation profile, i.e. exactly the visuals your config defines.
#
# The state lives in ~/.local/state/rice/ so it survives reboots and is never
# part of the git repo.

set -uo pipefail

CFG="$HOME/.config"
STATE_DIR="$HOME/.local/state/rice"
STATE_FILE="$STATE_DIR/performance"        # "on" or "off"
PPD_FILE="$STATE_DIR/performance-saved-ppd" # power profile to restore on OFF
SETTINGS="$CFG/hypr/user-settings.conf"
ANIM_FILE="$CFG/hypr/animations-active.conf"

mkdir -p "$STATE_DIR"

current_state() {
    local s
    s="$(cat "$STATE_FILE" 2>/dev/null || true)"
    [ "$s" = "on" ] && echo on || echo off
}

# Read a $variable from user-settings.conf (e.g. gapsIn -> 4).
setting() {
    sed -n "s/^[$]$1 *= *//p" "$SETTINGS" 2>/dev/null | head -n1 | tr -d '\r'
}

# Animations are "on" unless the active profile says enabled = false.
animations_enabled() {
    if grep -qE '^[[:space:]]*enabled[[:space:]]*=[[:space:]]*(false|0|no)' "$ANIM_FILE" 2>/dev/null; then
        echo 0
    else
        echo 1
    fi
}

hypr_batch() {
    # One IPC round-trip for all keywords. Silently skipped outside Hyprland.
    command -v hyprctl >/dev/null 2>&1 || return 0
    hyprctl --batch "$1" >/dev/null 2>&1 || true
}

set_ppd() {
    command -v powerprofilesctl >/dev/null 2>&1 || return 0
    powerprofilesctl set "$1" >/dev/null 2>&1 || true
}

apply_on() {
    hypr_batch "keyword animations:enabled 0 ; \
keyword decoration:blur:enabled 0 ; \
keyword decoration:shadow:enabled 0 ; \
keyword decoration:rounding 0 ; \
keyword general:gaps_in 0 ; \
keyword general:gaps_out 0 ; \
keyword decoration:active_opacity 1.0 ; \
keyword decoration:inactive_opacity 1.0"

    # Remember the user's power profile once, then switch to performance.
    if command -v powerprofilesctl >/dev/null 2>&1; then
        local cur
        cur="$(powerprofilesctl get 2>/dev/null || true)"
        if [ -n "$cur" ] && [ "$cur" != "performance" ] && [ ! -f "$PPD_FILE" ]; then
            echo "$cur" > "$PPD_FILE"
        fi
        set_ppd performance
    fi
}

apply_off() {
    local gi go ai ao blur_on anim
    gi="$(setting gapsIn)";        go="$(setting gapsOut)"
    ai="$(setting activeOpacity)"; ao="$(setting inactiveOpacity)"
    blur_on="$(setting blurEnabled)"
    local rounding; rounding="$(setting rounding)"
    anim="$(animations_enabled)"

    hypr_batch "keyword animations:enabled $anim ; \
keyword decoration:blur:enabled ${blur_on:-true} ; \
keyword decoration:shadow:enabled 1 ; \
keyword decoration:rounding ${rounding:-12} ; \
keyword general:gaps_in ${gi:-4} ; \
keyword general:gaps_out ${go:-10} ; \
keyword decoration:active_opacity ${ai:-1.0} ; \
keyword decoration:inactive_opacity ${ao:-1.0}"

    if [ -f "$PPD_FILE" ]; then
        set_ppd "$(cat "$PPD_FILE")"
        rm -f "$PPD_FILE"
    fi
}

restart_waybar() {
    # Swaps the bar config (full vs. performance). Takes ~0.2 s.
    "$CFG/hypr/scripts/waybar-launch.sh" >/dev/null 2>&1 || true
}

case "${1:-status}" in
    toggle)
        if [ "$(current_state)" = on ]; then "$0" off; else "$0" on; fi
        ;;
    on)
        echo on > "$STATE_FILE"
        apply_on
        restart_waybar
        command -v notify-send >/dev/null && notify-send -a "Performance" "Performance Mode ON" || true
        ;;
    off)
        echo off > "$STATE_FILE"
        apply_off
        restart_waybar
        command -v notify-send >/dev/null && notify-send -a "Performance" "Performance Mode OFF" || true
        ;;
    reapply)
        # Only acts when the saved state is ON (used at login / after reload).
        [ "$(current_state)" = on ] && apply_on || true
        ;;
    status)
        current_state
        ;;
    status-json)
        if [ "$(current_state)" = on ]; then
            echo '{"text":"󰓅 PERF","tooltip":"Performance Mode: ON (click to turn off)","class":"on"}'
        else
            echo '{"text":"󰾆 NORMAL","tooltip":"Performance Mode: OFF (click to turn on)","class":"off"}'
        fi
        ;;
    *)
        echo "Usage: $0 {toggle|on|off|reapply|status|status-json}" >&2
        exit 1
        ;;
esac

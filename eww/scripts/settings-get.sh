#!/usr/bin/env bash
# ~/.config/eww/scripts/settings-get.sh
# Emits current tunables as JSON, read by eww's defpoll in control.

SETTINGS="$HOME/.config/hypr/user-settings.conf"
ANIM_PROFILE_FILE="$HOME/.config/hypr/current_anim_profile"

get() {
    grep -oP "^\\\$$1 = \K.*" "$SETTINGS" 2>/dev/null | tr -d '\r'
}

gaps_in=$(get gapsIn); gaps_out=$(get gapsOut)
border_size=$(get borderSize); rounding=$(get rounding)
blur_enabled=$(get blurEnabled); blur_size=$(get blurSize)
active_opacity=$(get activeOpacity); inactive_opacity=$(get inactiveOpacity)
layout=$(get layout)
anim_profile=$(cat "$ANIM_PROFILE_FILE" 2>/dev/null || echo "smooth")

printf '{"gaps_in":"%s","gaps_out":"%s","border_size":"%s","rounding":"%s","blur_enabled":"%s","blur_size":"%s","active_opacity":"%s","inactive_opacity":"%s","layout":"%s","anim_profile":"%s"}\n' \
    "$gaps_in" "$gaps_out" "$border_size" "$rounding" "$blur_enabled" "$blur_size" \
    "$active_opacity" "$inactive_opacity" "$layout" "$anim_profile"

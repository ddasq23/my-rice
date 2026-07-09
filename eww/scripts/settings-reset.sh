#!/usr/bin/env bash
# ~/.config/eww/scripts/settings-reset.sh
# Restores default gaps/border/blur/opacity/layout and the Smooth animation
# profile, applied live.

set -euo pipefail
SET="$HOME/.config/eww/scripts/settings-set.sh"

"$SET" gaps_in 4
"$SET" gaps_out 10
"$SET" border_size 2
"$SET" rounding 12
"$SET" blur_enabled true
"$SET" blur_size 6
"$SET" active_opacity 1.0
"$SET" inactive_opacity 0.92
"$SET" layout dwindle

~/.config/eww/scripts/anim-profile-set.sh smooth

notify-send -a "Control Center" "Settings reset to defaults" 2>/dev/null || true

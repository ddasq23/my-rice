#!/usr/bin/env bash
# ~/.config/eww/scripts/settings-set.sh <key> <value>
# Applies a setting live via hyprctl keyword AND rewrites
# ~/.config/hypr/user-settings.conf so it survives a restart.
# No hyprctl reload involved — this is why it's instant.

set -euo pipefail

SETTINGS="$HOME/.config/hypr/user-settings.conf"
KEY="${1:-}"
VALUE="${2:-}"

if [ -z "$KEY" ] || [ -z "$VALUE" ]; then
    echo "Usage: settings-set.sh <key> <value>"
    exit 1
fi

# key -> (hyprlang variable name, live hyprctl keyword path)
declare -A VARNAME=(
    [gaps_in]="gapsIn"           [gaps_out]="gapsOut"
    [border_size]="borderSize"   [rounding]="rounding"
    [blur_enabled]="blurEnabled" [blur_size]="blurSize"
    [active_opacity]="activeOpacity" [inactive_opacity]="inactiveOpacity"
    [layout]="layout"
)
declare -A KEYWORD=(
    [gaps_in]="general:gaps_in"                 [gaps_out]="general:gaps_out"
    [border_size]="general:border_size"         [rounding]="decoration:rounding"
    [blur_enabled]="decoration:blur:enabled"     [blur_size]="decoration:blur:size"
    [active_opacity]="decoration:active_opacity" [inactive_opacity]="decoration:inactive_opacity"
    [layout]="general:layout"
)

VAR="${VARNAME[$KEY]:-}"
KW="${KEYWORD[$KEY]:-}"
if [ -z "$VAR" ]; then
    echo "Unknown key: $KEY"
    exit 1
fi

# Persist: replace the "$VAR = ..." line in user-settings.conf
sed -i "s/^\\\$${VAR} = .*/\\\$${VAR} = ${VALUE}/" "$SETTINGS"

# Apply live — instant, no reload/flicker
hyprctl keyword "$KW" "$VALUE" >/dev/null

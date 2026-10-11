#!/usr/bin/env bash
# ~/.config/eww/scripts/preset-set.sh <compact|cozy|spacious>

set -euo pipefail
SET="$HOME/.config/eww/scripts/settings-set.sh"
PRESET="${1:-}"

case "$PRESET" in
  compact)
    "$SET" gaps_in 2; "$SET" gaps_out 4
    "$SET" border_size 1; "$SET" rounding 6
    ;;
  cozy)
    "$SET" gaps_in 4; "$SET" gaps_out 10
    "$SET" border_size 2; "$SET" rounding 12
    ;;
  spacious)
    "$SET" gaps_in 8; "$SET" gaps_out 20
    "$SET" border_size 3; "$SET" rounding 18
    ;;
  *)
    echo "Usage: preset-set.sh <compact|cozy|spacious>"
    exit 1
    ;;
esac

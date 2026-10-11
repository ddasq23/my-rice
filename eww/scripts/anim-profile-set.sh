#!/usr/bin/env bash
# ~/.config/eww/scripts/anim-profile-set.sh <smooth|snappy|off>
# Animation curves can't be hot-patched one keyword at a time without a lot
# of hyprctl calls, so this is the one setting that uses `hyprctl reload` —
# still sub-second, just not zero-flicker like the others.

set -euo pipefail

PROFILE="${1:-}"
SRC="$HOME/.config/hypr/anim-profiles/$PROFILE.conf"
DEST="$HOME/.config/hypr/animations-active.conf"

if [ ! -f "$SRC" ]; then
    echo "Unknown profile: $PROFILE (expected smooth, snappy, or off)"
    exit 1
fi

cp "$SRC" "$DEST"
echo "$PROFILE" > "$HOME/.config/hypr/current_anim_profile"
hyprctl reload >/dev/null

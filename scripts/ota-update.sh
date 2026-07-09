#!/usr/bin/env bash
# ~/.config/scripts/ota-update.sh
#
# Pulls the latest version of this rice from GitHub and applies it to your
# live ~/.config, then reloads everything that can be reloaded live.
#
# Usage:
#   ota-update.sh              # update using the remembered repo URL
#   ota-update.sh <repo-url>   # first run / change remote, then remember it
#
# The repo URL is cached in ~/.config/.rice-source so you only have to pass
# it once. Re-run any time with no arguments after that, or wire it to a
# keybind / systemd timer for real "OTA" behavior.

set -euo pipefail

CFG="$HOME/.config"
SRC_FILE="$CFG/.rice-source"
REPO_URL="${1:-}"

if [ -n "$REPO_URL" ]; then
    echo "$REPO_URL" > "$SRC_FILE"
elif [ -f "$SRC_FILE" ]; then
    REPO_URL="$(cat "$SRC_FILE")"
else
    echo "No repo URL known yet."
    echo "Usage: ota-update.sh <git-repo-url>"
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "==> Fetching latest rice from $REPO_URL"
git clone --depth 1 --quiet "$REPO_URL" "$WORKDIR/rice"

# The repo may either BE the rice root, or wrap it in a subfolder
# (e.g. the zip you get from GitHub download). Detect either layout.
if [ -f "$WORKDIR/rice/hypr/hyprland.conf" ]; then
    RICE_ROOT="$WORKDIR/rice"
else
    RICE_ROOT="$(find "$WORKDIR/rice" -maxdepth 2 -name hyprland.conf -exec dirname {} \; | xargs dirname | head -n1)"
fi

if [ -z "$RICE_ROOT" ] || [ ! -d "$RICE_ROOT" ]; then
    echo "Couldn't find hypr/hyprland.conf in the cloned repo — aborting."
    exit 1
fi

echo "==> Backing up current config to $CFG.bak-$(date +%Y%m%d-%H%M%S)"
BACKUP="$CFG.bak-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
for d in hypr waybar wofi kitty dunst eww scripts themes wallpapers; do
    [ -d "$CFG/$d" ] && cp -r "$CFG/$d" "$BACKUP/" 2>/dev/null || true
done
[ -f "$CFG/current_theme" ] && cp "$CFG/current_theme" "$BACKUP/" 2>/dev/null || true

echo "==> Applying update"
CURRENT_THEME="$(cat "$CFG/current_theme" 2>/dev/null || echo "")"

for d in hypr waybar wofi kitty dunst eww scripts themes wallpapers; do
    if [ -d "$RICE_ROOT/$d" ]; then
        mkdir -p "$CFG/$d"
        cp -r "$RICE_ROOT/$d/." "$CFG/$d/"
    fi
done
chmod +x "$CFG"/scripts/*.sh 2>/dev/null || true
chmod +x "$CFG"/eww/scripts/*.sh 2>/dev/null || true

echo "==> Re-applying your current theme ($CURRENT_THEME) on top of the update"
if [ -n "$CURRENT_THEME" ] && [ -d "$CFG/themes/$CURRENT_THEME" ]; then
    "$CFG/scripts/theme-switch.sh" "$CURRENT_THEME" || true
fi

echo "==> Reloading Hyprland config"
hyprctl reload >/dev/null 2>&1 || true

notify-send -a "Rice OTA" "Updated to latest from GitHub" 2>/dev/null || true
echo "==> Done. Backup kept at: $BACKUP"

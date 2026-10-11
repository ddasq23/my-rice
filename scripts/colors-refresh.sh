#!/usr/bin/env bash
# ~/.config/scripts/colors-refresh.sh
#
# Re-renders every app's colors from the right palette and applies them live.
# Called by theme-switch.sh, color-source.sh and wallpaper-set.sh.
#
#   palette source = themes/<current theme>/palette.conf   (color source: theme)
#                  = wallpaper pywal palette               (color source: wallpaper)
#
# Live apply (no logout):
#   Hyprland border colors + cursor (hyprctl), Waybar + wofi + kitty + dunst,
#   Eww (reload), GTK/Qt files, dark/light hint via gsettings.
# Kitty windows that are already open keep their colors until reopened.

set -uo pipefail

CFG="$HOME/.config"
STATE="$HOME/.local/state/rice"
mkdir -p "$STATE"

THEME="$(cat "$CFG/current_theme" 2>/dev/null || echo catppuccin-mocha)"
MODE="$(cat "$STATE/color-source" 2>/dev/null || echo theme)"
THEME_PAL="$CFG/themes/$THEME/palette.conf"
PAL="$THEME_PAL"

notify() { command -v notify-send >/dev/null && notify-send -a "Colors" "$1" 2>/dev/null || true; }

if [ "$MODE" = "wallpaper" ]; then
    WALL="$(cat "$STATE/wallpaper" 2>/dev/null || true)"
    # No wallpaper chosen yet: use the theme's own wallpaper.
    if [ -z "$WALL" ]; then
        WALL="$CFG/wallpapers/$(sed -n 's/^wallpaper *= *//p' "$THEME_PAL" | head -n1)"
    fi
    if [ -n "$WALL" ] && [ -f "$WALL" ] && command -v wal >/dev/null; then
        if python3 "$CFG/scripts/theme-render.py" wal "$WALL" "$THEME_PAL" "$STATE/wal-palette.conf" 2>/dev/null; then
            PAL="$STATE/wal-palette.conf"
        else
            notify "pywal failed — using theme colors instead"
        fi
    else
        notify "pywal (wal) not installed — using theme colors"
    fi
fi

python3 "$CFG/scripts/theme-render.py" render "$PAL" || { notify "Color render failed"; exit 1; }

# ------------------------------------------------------------- live apply
# Hyprland (only when a session is running): borders, cursor, Waybar.
if command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; then
    A1="$(sed -n 's/^[$]borderActive1 *= *//p' "$CFG/hypr/colors.conf")"
    A2="$(sed -n 's/^[$]borderActive2 *= *//p' "$CFG/hypr/colors.conf")"
    IN="$(sed -n 's/^[$]borderInactive *= *//p' "$CFG/hypr/colors.conf")"
    CUR="$(sed -n 's/^[$]cursorTheme *= *//p' "$CFG/hypr/colors.conf")"
    SIZE="$(sed -n 's/^[$]cursorSize *= *//p' "$CFG/hypr/colors.conf")"

    hyprctl --batch "keyword general:col.active_border $A1 $A2 45deg ; keyword general:col.inactive_border $IN" >/dev/null 2>&1 || true

    # Fall back to Adwaita if the chosen cursor theme isn't installed.
    if ! find "$HOME/.local/share/icons" /usr/share/icons -maxdepth 1 -name "$CUR" 2>/dev/null | grep -q .; then
        notify "Cursor theme '$CUR' not installed — using Adwaita"
        CUR="Adwaita"
    fi
    hyprctl setcursor "$CUR" "${SIZE:-24}" >/dev/null 2>&1 || true

    # Waybar restarts with the new CSS (keeps performance-mode config if active).
    "$CFG/hypr/scripts/waybar-launch.sh" >/dev/null 2>&1 || true

    # Eww: recompile the SCSS in place if the sidebar is running.
    if pgrep -x eww >/dev/null 2>&1; then eww reload >/dev/null 2>&1 || true; fi

    # Dunst has no live reload: restart it (a fast process start).
    if command -v dunst >/dev/null; then
        pkill -x dunst 2>/dev/null || true
        setsid dunst >/dev/null 2>&1 &
    fi
fi


# GTK/Qt: dark/light hint for apps that follow the portal setting.
DARK="$(sed -n 's/^dark = *//p' "$PAL" | head -n1)"
if command -v gsettings >/dev/null; then
    if [ "$DARK" = "true" ]; then SCHEME=prefer-dark; else SCHEME=prefer-light; fi
    gsettings set org.gnome.desktop.interface color-scheme "$SCHEME" >/dev/null 2>&1 || true
fi

notify "Colors: $MODE ($THEME)"

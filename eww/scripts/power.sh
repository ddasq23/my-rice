#!/usr/bin/env bash
# ~/.config/eww/scripts/power.sh
# Requires: power-profiles-daemon (powerprofilesctl)

case "$1" in
  current)
    powerprofilesctl get 2>/dev/null || echo "balanced"
    ;;
  set)
    powerprofilesctl set "$2"
    ;;
esac

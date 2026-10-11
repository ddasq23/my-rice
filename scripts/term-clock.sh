#!/usr/bin/env bash
# ~/.config/scripts/term-clock.sh
# Toggles a small floating terminal running tty-clock.
# Requires: tty-clock (pacman -S tty-clock / dnf install tty-clock)

if hyprctl clients | grep -q "clock-term"; then
    hyprctl dispatch closewindow "class:^(clock-term)$"
    exit 0
fi

kitty --class clock-term -e tty-clock -c -C 5 -f "%A %d %B"

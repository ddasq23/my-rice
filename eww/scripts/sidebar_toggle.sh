#!/usr/bin/env bash
# ~/.config/eww/scripts/sidebar_toggle.sh

if eww active-windows | grep -q "sidebar"; then
    eww close sidebar
else
    eww open sidebar
fi

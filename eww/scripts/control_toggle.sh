#!/usr/bin/env bash
# ~/.config/eww/scripts/control_toggle.sh
if eww active-windows | grep -q "control"; then
    eww close control
else
    eww open control
fi

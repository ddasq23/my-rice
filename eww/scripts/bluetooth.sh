#!/usr/bin/env bash
# ~/.config/eww/scripts/bluetooth.sh
# Requires: bluez (bluetoothctl)

case "$1" in
  status)
    if bluetoothctl show | grep -q "Powered: yes"; then
      echo "on"
    else
      echo "off"
    fi
    ;;
  devices)
    connected=$(bluetoothctl devices Connected 2>/dev/null | cut -d' ' -f3- | paste -sd, -)
    if [ -n "$connected" ]; then
      echo "$connected"
    else
      echo "No devices connected"
    fi
    ;;
  toggle)
    if bluetoothctl show | grep -q "Powered: yes"; then
      bluetoothctl power off
    else
      bluetoothctl power on
    fi
    ;;
esac

#!/usr/bin/env bash
# ~/.config/eww/scripts/network.sh
# Requires: NetworkManager (nmcli)

case "$1" in
  status)
    if nmcli radio wifi | grep -q "enabled"; then
      echo "on"
    else
      echo "off"
    fi
    ;;
  name)
    # Show the SSID of the active connection, or a friendly fallback.
    # (The old `... | head -n1 || echo` never took the fallback: head exits 0
    # even when there is no match, so the card just showed a blank line.)
    ssid=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2; exit}')
    echo "${ssid:-Not connected}"
    ;;
  data)
    # Rough session RX/TX totals for the active interface, in MB
    iface=$(ip route | awk '/default/ {print $5; exit}')
    if [ -n "$iface" ]; then
      rx=$(( $(cat /sys/class/net/"$iface"/statistics/rx_bytes) / 1024 / 1024 ))
      tx=$(( $(cat /sys/class/net/"$iface"/statistics/tx_bytes) / 1024 / 1024 ))
      echo "↓ ${rx}MB  ↑ ${tx}MB"
    else
      echo "No active interface"
    fi
    ;;
  toggle)
    if nmcli radio wifi | grep -q "enabled"; then
      nmcli radio wifi off
    else
      nmcli radio wifi on
    fi
    ;;
esac

#!/usr/bin/env bash
# ~/.config/eww/scripts/pomodoro.sh
# Modes: idle -> work (25m) -> break (5m) -> work ... loops.
# `listen` is meant to be run once by eww's deflisten; start/pause/reset
# are called from the sidebar buttons and just flip a flag in the state file.

STATE_FILE="/tmp/eww_pomodoro_state"
WORK_LEN=1500   # 25 min
BREAK_LEN=300   # 5 min

fmt() {
  local s=$1
  printf "%02d:%02d" $((s / 60)) $((s % 60))
}

init_state() {
  echo "idle:0:0" > "$STATE_FILE"
}

[ -f "$STATE_FILE" ] || init_state

case "$1" in
  start)
    mode=$(cut -d: -f1 "$STATE_FILE")
    remaining=$(cut -d: -f2 "$STATE_FILE")
    if [ "$mode" = "idle" ] || [ "$remaining" -le 0 ]; then
      echo "work:${WORK_LEN}:1" > "$STATE_FILE"
    else
      echo "${mode}:${remaining}:1" > "$STATE_FILE"
    fi
    ;;
  pause)
    mode=$(cut -d: -f1 "$STATE_FILE")
    remaining=$(cut -d: -f2 "$STATE_FILE")
    echo "${mode}:${remaining}:0" > "$STATE_FILE"
    ;;
  reset)
    echo "idle:${WORK_LEN}:0" > "$STATE_FILE"
    ;;
  listen)
    init_state
    echo "idle:${WORK_LEN}:0" > "$STATE_FILE"
    while true; do
      mode=$(cut -d: -f1 "$STATE_FILE")
      remaining=$(cut -d: -f2 "$STATE_FILE")
      running=$(cut -d: -f3 "$STATE_FILE")

      if [ "$running" = "1" ]; then
        remaining=$((remaining - 1))
        if [ "$remaining" -le 0 ]; then
          if [ "$mode" = "work" ]; then
            mode="break"
            remaining=$BREAK_LEN
            notify-send "Pomodoro" "Work session done — take a break." 2>/dev/null
          else
            mode="work"
            remaining=$WORK_LEN
            notify-send "Pomodoro" "Break's over — back to work." 2>/dev/null
          fi
        fi
        echo "${mode}:${remaining}:1" > "$STATE_FILE"
      fi

      printf '{"mode":"%s","remaining":"%s"}\n' "$mode" "$(fmt "$remaining")"
      sleep 1
    done
    ;;
esac

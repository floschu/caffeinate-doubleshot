#!/bin/bash
# Keeps the Mac awake with the lid closed while any caffeinate process runs.
# Runs as root via launchd. Toggles `pmset disablesleep`.

INTERVAL=3
CONF=/usr/local/etc/caffeinate-doubleshot.conf   # written by `doubleshot battery`
# Start from the current flag. A leftover 1 (a killed daemon, a crash) then counts
# as held awake, so set_state puts a Mac with a closed lid to sleep.
state=0; pmset -g | grep -qE 'SleepDisabled[[:space:]]+1' && state=1

log() { echo "$(date "+%Y-%m-%d %H:%M:%S") $*"; }   # launchd writes stdout to /var/log/caffeinate-doubleshot.log

lid_closed() {
  ioreg -r -k AppleClamshellState -d 4 | grep -q '"AppleClamshellState" = Yes'
}

# On battery below this %, allow sleep even if caffeinate runs. Default 15.
# Parsed, not sourced, so the root daemon never runs code from the file.
min_battery() {
  local v
  v=$(grep -Eo '^MIN_BATTERY=[0-9]+$' "$CONF" 2>/dev/null | cut -d= -f2)
  echo "${v:-15}"
}

# True when running on battery and charge is below MIN_BATTERY.
battery_low() {
  local batt pct
  batt=$(pmset -g batt)
  grep -q "'Battery Power'" <<<"$batt" || return 1
  pct=$(grep -Eo '[0-9]+%' <<<"$batt" | head -1 | tr -d %)
  [ -n "$pct" ] && [ "$pct" -lt "$MIN_BATTERY" ]
}

set_state() {
  local prev=$state
  pmset -a disablesleep "$1"
  state="$1"
  log "disablesleep=$1"
  # If caffeinate ended while the lid is shut, sleep now instead of
  # staying awake until the next lid event. Only when sleep was disabled
  # before: a start with the lid closed (boot in clamshell mode,
  # `doubleshot enable` over SSH) must not put it to sleep.
  if [ "$1" = 0 ] && [ "$prev" = 1 ] && lid_closed; then
    log "lid closed, sleeping now"
    pmset sleepnow
  fi
}

cleanup() { pmset -a disablesleep 0; log "stopped, disablesleep=0"; exit 0; }
trap cleanup TERM INT HUP

log "started, disablesleep=$state"
while true; do
  MIN_BATTERY=$(min_battery)
  want=0
  if pgrep -x caffeinate >/dev/null; then
    if battery_low; then
      [ "$state" = 1 ] && log "battery below ${MIN_BATTERY}%, allowing sleep"
    else
      want=1
    fi
  fi
  [ "$want" != "$state" ] && set_state "$want"
  sleep "$INTERVAL"
done

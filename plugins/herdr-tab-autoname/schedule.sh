#!/bin/sh
# Coalesce Herdr event hooks into one transient tab-naming pass. Herdr launches
# this command asynchronously; no process remains after the event burst settles.

set -eu

state_dir=${HERDR_PLUGIN_STATE_DIR:?HERDR_PLUGIN_STATE_DIR is required}
socket_path=${HERDR_SOCKET_PATH:?HERDR_SOCKET_PATH is required}
settle_seconds=${HERDR_TAB_AUTONAME_SETTLE_SECONDS:-0.75}
worker=${HERDR_TAB_AUTONAME_WORKER:-$HOME/.local/bin/herdr-tab-autoname}
lock_file="$state_dir/scheduler.lockfile"
lock_candidate="$lock_file.$$"
recovery_lock="$state_dir/scheduler.recovery.lock"
owns_lock=false
owns_recovery_lock=false

mkdir -p "$state_dir"
socket_key=$(printf '%s' "$socket_path" | cksum | awk '{print $1}')
pending="$state_dir/pending.$socket_key"
temporary="$pending.$$"
printf '%s\n' "$socket_path" >"$temporary"
mv -f "$temporary" "$pending"

pending_exists() {
  set -- "$state_dir"/pending.*
  [ -e "$1" ]
}

try_acquire_lock() {
  # Link a complete owner file into place so contenders can never observe a
  # newly acquired lock before its PID has been written.
  printf '%s\n' "$$" >"$lock_candidate"
  if ln "$lock_candidate" "$lock_file" 2>/dev/null; then
    rm -f "$lock_candidate"
    owns_lock=true
    return 0
  fi
  rm -f "$lock_candidate"
  return 1
}

acquire_lock() {
  try_acquire_lock && return 0

  # Serialize stale-lock recovery so two hooks cannot both replace the same
  # dead owner and then run workers concurrently.
  mkdir "$recovery_lock" 2>/dev/null || return 1
  owns_recovery_lock=true
  owner=$(cat "$lock_file" 2>/dev/null || true)
  if [ -z "$owner" ] || ! kill -0 "$owner" 2>/dev/null; then
    rm -f "$lock_file"
  fi
  rmdir "$recovery_lock"
  owns_recovery_lock=false

  try_acquire_lock
}

release_lock() {
  rm -f "$lock_candidate"
  if [ "$owns_recovery_lock" = true ]; then
    rm -rf "$recovery_lock"
    owns_recovery_lock=false
  fi
  if [ "$owns_lock" = true ]; then
    rm -f "$lock_file"
    owns_lock=false
  fi
}

trap release_lock 0 1 2 15
acquire_lock || exit 0

ownership_state="$state_dir/ownership.json"
legacy_state=${XDG_CACHE_HOME:-$HOME/.cache}/herdr-tab-autoname-state.json
if [ ! -e "$ownership_state" ] && [ -r "$legacy_state" ]; then
  migration="$ownership_state.$$.tmp"
  cp "$legacy_state" "$migration"
  chmod 600 "$migration"
  mv -f "$migration" "$ownership_state"
fi

while :; do
  sleep "$settle_seconds"

  set -- "$state_dir"/pending.*
  if [ -e "$1" ]; then
    for pending_file do
      [ -f "$pending_file" ] || continue
      processing="$state_dir/processing.$$.${pending_file##*/}"
      if ! mv "$pending_file" "$processing" 2>/dev/null; then
        continue
      fi
      pending_socket=$(cat "$processing")
      rm -f "$processing"
      if [ -S "$pending_socket" ]; then
        # Herdr captures stderr in plugin logs. Keep ownership decisions there
        # so an unexpected manual-name classification is diagnosable later.
        HERDR_SOCKET_PATH=$pending_socket \
          HERDR_TAB_AUTONAME_STATE_PATH=$ownership_state \
          "$worker" --once --verbose
      fi
    done
  fi

  # Events raised during a naming pass need one more pass. Releasing and then
  # reacquiring closes the race where an event arrives while the lock exits.
  pending_exists && continue
  release_lock
  if pending_exists && acquire_lock; then
    continue
  fi
  break
done

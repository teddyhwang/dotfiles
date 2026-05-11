#!/usr/bin/env bash
# resurrect-guard.sh
#
# Wired up as @resurrect-hook-post-save-layout. Runs after tmux-resurrect
# writes a new save file but BEFORE it repoints the `last` symlink.
#
# Why: a fresh tmux server (e.g. after a crash, kill-server, or first launch
# of the day) starts with one default zsh pane. If continuum's 5-minute
# autosave fires before the user restores, the trivial state is written and
# `last` is updated to point at it -- destroying the previous good save.
#
# Strategy: if the new save looks too trivial AND the existing `last` looks
# substantially richer, copy the existing `last` target over the new file.
# tmux-resurrect's own `files_differ` check then sees no change and deletes
# the new file, leaving `last` pointing at the original good save.
#
# Trivially safe: if the new save is genuinely a 1-pane state that the user
# really wanted (rare), the next save with that same content is still a no-op
# either way. The guard only activates when last is meaningfully bigger.

set -u

new_file="${1:-}"
[ -z "$new_file" ] && exit 0
[ -f "$new_file" ] || exit 0

last_link="$(dirname "$new_file")/last"
[ -L "$last_link" ] || exit 0

last_target="$(readlink "$last_link")"
case "$last_target" in
  /*) ;;                                                # absolute -- use as-is
  *)  last_target="$(dirname "$new_file")/$last_target" ;;
esac
[ -f "$last_target" ] || exit 0

# Count `pane` lines (the only line type that represents real workload).
new_panes="$(grep -c '^pane	' "$new_file" 2>/dev/null || echo 0)"
last_panes="$(grep -c '^pane	' "$last_target" 2>/dev/null || echo 0)"

# Heuristics:
#   - new save has <= 2 panes (trivial / fresh tmux startup), AND
#   - last save has at least 3x as many panes (meaningfully richer).
# Adjust thresholds if you ever genuinely run with very few panes.
TRIVIAL_PANE_THRESHOLD=2
RICHER_RATIO=3

if [ "$new_panes" -le "$TRIVIAL_PANE_THRESHOLD" ] \
   && [ "$last_panes" -ge $((new_panes * RICHER_RATIO + 1)) ] \
   && [ "$last_panes" -gt "$TRIVIAL_PANE_THRESHOLD" ]; then
  # Make the new save byte-identical to the existing last target.
  # save.sh will see files_differ == false and `rm` the new file,
  # leaving `last` untouched.
  cp -f "$last_target" "$new_file"
  # Optional: log to stderr so it shows up in tmux server log if enabled.
  printf 'resurrect-guard: vetoed trivial save (%d panes) — kept last (%d panes)\n' \
    "$new_panes" "$last_panes" >&2
fi

exit 0

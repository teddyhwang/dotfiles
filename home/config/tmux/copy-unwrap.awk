#!/usr/bin/awk -f
# Strip wrap-induced line breaks from a tmux selection.
#
# Detects two cases and joins the rows:
#   1. Soft-wrap: the previous physical row filled to >= pane_width.
#      (tmux autowrap; matters when an application wrote text without
#      embedded newlines and tmux wrapped the visible grid.)
#   2. TUI hard-wrap with continuation indent: the current physical row
#      starts with a single leading space followed by a non-space.
#      (Pi, Claude Code, and other TUIs that pre-wrap to terminal width
#      and prefix continuation rows with " " for visual hierarchy.)
#
# Blank lines are preserved as paragraph separators and prevent joining
# across the gap. The heuristic deliberately keeps the leading-space
# character on the continuation row so it becomes the natural word
# boundary on join (e.g. "adding" + " perceived" -> "adding perceived").
#
# Invoked from tmux's copy-pipe with `awk -v w=#{pane_width} -f <this>`.

BEGIN {
  state = "INIT"  # INIT (no content yet) | ACTIVE (accumulating) | BLANK (just emitted a blank)
  buf = ""
  last_row_len = 0  # length of the most recently appended physical row, NOT cumulative buf
}

function flush_active() {
  if (state == "ACTIVE") {
    print buf
    buf = ""
    last_row_len = 0
  }
}

{
  if ($0 == "") {
    flush_active()
    print ""
    state = "BLANK"
    next
  }

  # Non-blank line.
  if (state != "ACTIVE") {
    buf = $0
    last_row_len = length($0)
    state = "ACTIVE"
    next
  }

  # ACTIVE: decide join vs break.
  # Join if the previous physical row was full-width (soft-wrap) OR
  # the current row begins with a single leading space (TUI continuation).
  # last_row_len tracks ONLY the previous physical row, not the accumulated
  # buffer — otherwise the soft-wrap check fires on every line after the first
  # join, gluing unrelated lines together.
  if (last_row_len >= w || $0 ~ /^ [^ ]/) {
    buf = buf $0
  } else {
    print buf
    buf = $0
  }
  last_row_len = length($0)
}

END {
  flush_active()
}

#!/usr/bin/env bash
# fzf pickers styled like Herdr's built-in overlays. Herdr runs each one in a
# titled popup (see herdr-plugin.toml), so the popup border carries the title.
#
# The colors are ANSI indices that mirror Herdr's "terminal" theme, so the
# pickers follow the active tinty scheme the same way Herdr's own UI does.
#
# Every picker is on the path of a key press, so each one starts as few
# processes as possible: one jq pass per list, parallel Herdr calls, and no jq
# just to read the plugin context.

set -euo pipefail

herdr=${HERDR_BIN_PATH:-}
[ -n "$herdr" ] || herdr=herdr
self=${BASH_SOURCE[0]}
case $self in /*) ;; *) self=$PWD/$self ;; esac
tab=$'\t'
separator=$'\037'
state_dir=${HERDR_PLUGIN_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/herdr/plugins/teddyhwang.pickers}

# Herdr ids are plain tokens, so a pattern match reads them without jq.
context=${HERDR_PLUGIN_CONTEXT_JSON:-}
context_workspace_id="" context_tab_id=""
workspace_pattern='"workspace_id"[[:space:]]*:[[:space:]]*"([^"]*)"'
tab_pattern='"tab_id"[[:space:]]*:[[:space:]]*"([^"]*)"'
if [[ $context =~ $workspace_pattern ]]; then context_workspace_id=${BASH_REMATCH[1]}; fi
if [[ $context =~ $tab_pattern ]]; then context_tab_id=${BASH_REMATCH[1]}; fi

cols=${HERDR_PICKER_COLUMNS:-}
if [ -z "$cols" ]; then
  size=$(stty size </dev/tty 2>/dev/null || true)
  cols=${size#* }
fi
case $cols in '' | *[!0-9]*) cols=80 ;; esac

# Shared jq helpers. render($cols) turns a {key, label, detail, status} object
# into one NUL-terminated fzf item with two lines, like Herdr's worktree picker:
# a bold label with the status right-aligned, then the detail underneath.
# Optional {tree, stem} prefixes draw a nested row, as in Herdr's sidebar.
# Widths count emoji and CJK as two cells so the status column stays aligned.
jq_defs='
def tilde: (env.HOME // "") as $home
  | if $home != "" and startswith($home) then "~" + .[($home | length):] else . end;
def count(n; noun): "\(n) \(noun)\(if n == 1 then "" else "s" end)";
def field: (. // "") | tostring | gsub("[\t\n\r]"; " ");
def cells: explode | map(
  if . == 8205 or (. >= 768 and . <= 879) or (. >= 65024 and . <= 65039) then 0
  elif (. >= 4352 and . <= 4447) or (. >= 11904 and . <= 42191)
    or (. >= 44032 and . <= 55203) or (. >= 63744 and . <= 64255)
    or (. >= 65072 and . <= 65103) or (. >= 65280 and . <= 65376)
    or (. >= 65504 and . <= 65510) or (. >= 127744 and . <= 129791)
    or (. >= 131072 and . <= 262141) then 2
  else 1 end) | add // 0;
def render($cols): (.label | field) as $label | (.status | field) as $status
  | (.tree // "") as $tree
  # One column each for the leading space, trailing space, and scrollbar.
  | ([$cols - 3 - ($tree | cells) - ($label | cells) - ($status | cells), 1] | max) as $pad
  | (if $tree == "" then "\u001b[1m \($label)\u001b[22m"
     else " \u001b[90m\($tree)\u001b[39;1m\($label)\u001b[22m" end) as $title
  | (if $tree == "" then "" else "\u001b[90m\(.stem)\u001b[39m" end) as $stem
  | "\(.key | field)\t\($title)\(" " * $pad)\($status)\n \($stem)\(.detail | field)\u0000";
'

# Reads rendered items on stdin and prints the chosen key. Extra arguments are
# passed to fzf.
pick() {
  local noun=$1 placeholder=$2 action=$3 primary cancel left footer info
  shift 3

  primary=" ↵ $action "
  cancel=" esc cancel "
  left=$(((cols - ${#primary} - 2 - ${#cancel}) / 2))
  ((left > 0)) || left=0
  printf -v footer '%*s\033[1;90;44m%s\033[0m  \033[1m%s\033[0m' "$left" "" "$primary" "$cancel"

  # shellcheck disable=SC2016 # Expanded by fzf's info command, not here.
  info='n=$FZF_MATCH_COUNT t=$FZF_TOTAL_COUNT w=$HERDR_PICKER_NOUN
if [ "$t" = 0 ] && [ -n "${HERDR_PICKER_LOADED:-}" ] && [ ! -e "$HERDR_PICKER_LOADED" ]; then
  printf "loading… "; exit
fi
[ "$t" = 1 ] || w="${w}s"
if [ "$n" = "$t" ]; then printf "%s %s " "$t" "$w"; else printf "%s/%s %s " "$n" "$t" "$w"; fi'

  # fzf runs the info command on every redraw; bash starts faster than zsh.
  HERDR_PICKER_NOUN=$noun FZF_DEFAULT_OPTS="" FZF_DEFAULT_OPTS_FILE="" fzf \
    --read0 --ansi --layout=reverse --no-sort --with-shell='bash -c' \
    --delimiter="$tab" --with-nth=2.. --accept-nth=1 \
    --highlight-line --pointer='' --marker='' --scrollbar='│' \
    --prompt=' / ' --ghost="$placeholder" \
    --info=inline-right --info-command="$info" \
    --footer="$footer" --footer-border=none \
    --color='fg:-1,bg:-1,fg+:8:regular,bg+:4,gutter:-1,hl:4:regular,hl+:0:underline' \
    --color='prompt:7:regular,query:-1:regular,ghost:7,info:7,separator:8,scrollbar:8' \
    --color='header:-1,footer:-1,pointer:8,marker:8,spinner:4' \
    "$@" || true
}

notify() {
  "$herdr" notification show "$1" --body "$2" >/dev/null 2>&1 || true
}

# Shows a Herdr toast for a failed CLI call. Errors arrive as JSON on stderr.
notify_error() {
  local title=$1 output=$2 message
  message=$(jq -r '.error.message // empty' <<<"$output" 2>/dev/null || true)
  [ -n "$message" ] || message=${output:-"herdr exited with an error"}
  notify "$title" "$message"
}

# Sets $branch to the branch checked out at $1, or empty when detached. It
# reads Git's files directly so a picker with many worktrees forks nothing.
checkout_branch() {
  local git_dir=$1/.git line="" head=""
  branch=""
  if [ -f "$git_dir" ]; then
    IFS= read -r line <"$git_dir" 2>/dev/null || true
    line=${line#gitdir: }
    case $line in /*) git_dir=$line ;; *) git_dir=$1/$line ;; esac
  fi
  IFS= read -r head <"$git_dir/HEAD" 2>/dev/null || true
  case $head in "ref: refs/heads/"*) branch=${head#ref: refs/heads/} ;; esac
}

# Rows follow Herdr's sidebar: a linked worktree whose parent checkout is open
# is listed under it, and is labelled by its branch unless it was named by hand.
workspace_rows='
.result.workspaces // [] | . as $ws
| (reduce range($ws | length) as $i ({};
    ($ws[$i].worktree.repo_key // null) as $key
    | if $key == null then . else .[$key] += [$i] end)) as $members
| ($members | with_entries(select((.value | length) >= 2
    and any(.value[]; $ws[.].worktree.is_linked_worktree | not)))) as $groups
| (reduce range($ws | length) as $i ({seen: {}, rows: []};
    ($ws[$i].worktree.repo_key // null) as $key
    | if $key == null or $groups[$key] == null then .rows += [{i: $i}]
      elif .seen[$key] then .
      else
        ([$groups[$key][] | select($ws[.].worktree.is_linked_worktree | not)][0]) as $parent
        | ([$groups[$key][] | select(. != $parent)]) as $children
        | .seen[$key] = true
        | .rows += [{i: $parent}] + [range($children | length) as $n
            | {i: $children[$n], last: ($n == ($children | length) - 1)}]
      end)).rows[]
| . as $row | $ws[$row.i]
| (.worktree.checkout_path // "") as $path
| {
    key: .workspace_id,
    label: (if $row.last == null then .label
      # Herdr names an unnamed linked worktree after its checkout directory.
      elif .label == ($path | split("/") | map(select(. != "")) | last)
      then ($branches[$path] // .label | sub("^worktree/"; ""))
      else .label end),
    detail: ([count(.tab_count; "tab"), count(.pane_count; "pane")]
      + (if $path != "" then [$path | tilde] else [] end)
      | join(" · ")),
    status: ([if .focused then "current" else empty end,
      if .agent_status == "unknown" then empty else .agent_status end] | join(" · "))
  }
  + (if $row.last == null then {}
    elif $row.last then {tree: "  └─ ", stem: "     "}
    else {tree: "  ├─ ", stem: "  │  "} end)
| render($cols)'

pick_workspace() {
  local listing selected checkout branch
  local -a branches=()
  listing=$("$herdr" workspace list)
  # Only linked worktrees need their branch, and most listings have none.
  if [[ $listing == *'"is_linked_worktree":true'* ]]; then
    while IFS= read -r checkout; do
      checkout_branch "$checkout"
      [ -z "$branch" ] || branches+=("$checkout" "$branch")
    done < <(jq -r '.result.workspaces[]?.worktree | select(.is_linked_worktree == true) | .checkout_path' <<<"$listing")
  fi
  selected=$(jq -j --argjson cols "$cols" "$jq_defs"'
    ($ARGS.positional | [range(0; length; 2) as $n | {key: .[$n], value: .[$n + 1]}] | from_entries) as $branches
    | '"$workspace_rows" --args ${branches[@]+"${branches[@]}"} <<<"$listing" |
    pick workspace "filter workspaces" switch)
  [ -z "$selected" ] || "$herdr" workspace focus "$selected" >/dev/null
}

pick_agent() {
  local selected
  # Process substitution runs the three Herdr calls in parallel.
  selected=$(jq -jn --argjson cols "$cols" \
    --slurpfile workspaces <("$herdr" workspace list) \
    --slurpfile tabs <("$herdr" tab list) \
    --slurpfile agents <("$herdr" agent list) "$jq_defs"'
    ($workspaces[0].result.workspaces // [] | map({key: .workspace_id, value: .label}) | from_entries) as $workspace
    | ($tabs[0].result.tabs // [] | map({key: .tab_id, value: .label}) | from_entries) as $tab
    # Match the sidebar order set by agent-view.py: blocked agents first, then
    # finished ones (done, then idle), then working ones, with the newest
    # state change first in each group.
    | $agents[0].result.agents // []
    | sort_by(
        ({blocked: 0, done: 1, idle: 2, unknown: 3, working: 4}[.agent_status | tostring] // 5),
        -(.state_change_seq // 0))
    | .[]
    | {
        key: .pane_id,
        label: ($tab[.tab_id] // .tab_id),
        detail: ([$workspace[.workspace_id] // .workspace_id,
          ((.terminal_title_stripped // "") | if . == "" then empty else . end)
            // (.cwd // "" | tilde)] | join(" · ")),
        status: ([if .focused then "current" else empty end, .agent,
          if .agent_status == "unknown" then empty else .agent_status end] | join(" · "))
      }
    | render($cols)' | pick agent "filter agents" switch)
  # Herdr 0.9.0's agent focus updates server state without moving the attached
  # client's viewport (herdrdev/herdr#3760). The raw pane.focus method still
  # projects to the client and also selects the exact pane in a split tab.
  [ -z "$selected" ] || "$HOME/.local/bin/herdr-focus-pane" "$selected" >/dev/null
}

pick_join_pane() {
  local selected
  [ -n "$context_workspace_id" ] && [ -n "$context_tab_id" ] || return 0
  selected=$(jq -jn --argjson cols "$cols" --arg workspace "$context_workspace_id" --arg current_tab "$context_tab_id" \
    --slurpfile panes <("$herdr" pane list) \
    --slurpfile tabs <("$herdr" tab list --workspace "$context_workspace_id") "$jq_defs"'
    ($tabs[0].result.tabs // [] | map({key: .tab_id, value: .label}) | from_entries) as $tab
    | $panes[0].result.panes // [] | .[]
    | select(.workspace_id == $workspace and .tab_id != $current_tab)
    | {
        key: .pane_id,
        label: ($tab[.tab_id] // .tab_id),
        detail: (.foreground_cwd // .cwd // "" | tilde),
        status: (if .agent then
          [.agent, if .agent_status == "unknown" then empty else .agent_status end] | join(" · ")
        else "shell" end)
      }
    | render($cols)' | pick pane "filter panes" join)
  [ -z "$selected" ] ||
    "$herdr" pane move "$selected" --tab "$context_tab_id" --split right --focus >/dev/null
}

# Rows match Herdr's native worktree picker: bare and prunable checkouts are
# hidden, and the status is current, open, detached, or root. Items are keyed by
# path so a refresh can keep the cursor on the same checkout.
worktree_rows='
# World checkouts live at <world>/trees/<id>/src and are all labelled "git",
# so name them by tree id. Other checkouts use their directory.
def checkout_name: (.path | split("/") | map(select(. != ""))) as $parts
  | if ($parts | length) >= 3 and $parts[-1] == "src" and $parts[-3] == "trees"
    then $parts[-2] else ($parts[-1] // .path) end;
.result.worktrees // [] | .[]
| select((.is_bare | not) and (.is_prunable | not))
| {
    key: .path,
    label: (.branch // checkout_name),
    detail: (.path | tilde),
    status: (if .open_workspace_id and .open_workspace_id == $current then "current"
      elif .open_workspace_id then "open"
      elif .branch then ""
      elif .is_detached and .is_linked_worktree then "detached"
      else "root" end)
  }
| render($cols)'

render_worktrees() {
  jq -j --argjson cols "$cols" --arg current "$context_workspace_id" "$jq_defs$worktree_rows"
}

list_worktrees() {
  "$herdr" worktree list ${context_workspace_id:+--workspace "$context_workspace_id"}
}

worktree_cache() {
  local session=${HERDR_SESSION:-default} workspace=${context_workspace_id:-none}
  printf '%s/worktrees/%s.%s.json\n' "$state_dir" "${session//[^A-Za-z0-9._-]/_}" "${workspace//[^A-Za-z0-9._-]/_}"
}

# Stores a fresh listing for this picker run and as the next run's cache.
save_listing() {
  local run=$1 listing=$2 cache
  printf '%s\n' "$listing" >"$run/listing.tmp" && mv -f "$run/listing.tmp" "$run/listing.json"
  cache=$(worktree_cache)
  mkdir -p "${cache%/*}" &&
    printf '%s\n' "$listing" >"$cache.$$" &&
    mv -f "$cache.$$" "$cache" || rm -f "$cache.$$"
}

# Runs inside fzf after the cached rows are shown, and swaps in the fresh rows
# without moving the cursor. The Herdr server answers `worktree list` on its
# main loop, running git and any worktree provider (World's dev-tree provider
# takes about 250 ms), and draws nothing else meanwhile. Starting the refresh
# after a short delay lets the cached rows reach the screen first.
refresh_worktrees() {
  local run=$1 delay=${2:-0} listing
  [ "$delay" = 0 ] || sleep "$delay"
  if ! listing=$(list_worktrees 2>"$run/stderr"); then
    mv -f "$run/stderr" "$run/error"
    echo abort
    return 0
  fi
  save_listing "$run" "$listing"
  render_worktrees <<<"$listing" >"$run/items"
  if [ ! -s "$run/items" ]; then
    : >"$run/empty"
    echo abort
    return 0
  fi
  printf 'track-current+reload-sync:cat %q\n' "$run/items"
}

# Replaces Herdr's native open-worktree picker, which only moves with the
# arrow keys.
pick_worktree() {
  local run cache delay refresh selected listing fields found open_id source_id source_path path output
  run=$(mktemp -d "${TMPDIR:-/tmp}/herdr-worktree.XXXXXX")
  # shellcheck disable=SC2064 # Expand the run directory now.
  trap "rm -rf '$run'" EXIT
  cache=$(worktree_cache)
  # With nothing cached there is nothing to draw first, so refresh at once.
  delay=0
  [ ! -s "$cache" ] || delay=${HERDR_PICKER_REFRESH_DELAY:-0.15}
  printf -v refresh 'exec %q _refresh-worktree %q %q' "$self" "$run" "$delay"
  export HERDR_PICKER_COLUMNS=$cols HERDR_PICKER_LOADED=$run/listing.json

  selected=$({ if [ -s "$cache" ]; then render_worktrees <"$cache" 2>/dev/null || true; fi; } |
    pick checkout "filter worktrees" open --id-nth=1 \
      --bind "load:unbind(load)+bg-transform:$refresh")

  if [ -e "$run/error" ]; then
    notify_error "open worktree" "$(<"$run/error")"
    return 0
  fi
  if [ -e "$run/empty" ]; then
    notify "open worktree" "No Git worktrees found for this repo."
    return 0
  fi
  [ -n "$selected" ] || return 0

  # Act on fresh data only. When Enter beats the refresh, fzf has already
  # stopped it, so list again before acting on a possibly stale cached row.
  if [ -s "$run/listing.json" ]; then
    listing=$(<"$run/listing.json")
  elif listing=$(list_worktrees 2>"$run/stderr"); then
    save_listing "$run" "$listing"
  else
    notify_error "open worktree" "$(<"$run/stderr")"
    return 0
  fi

  fields=$(jq -r --arg path "$selected" "$jq_defs"'
    [.result.worktrees // [] | .[] | select((.path | field) == $path)][0] as $entry
    | [if $entry then "found" else "" end, ($entry.open_workspace_id // ""),
        (.result.source.source_workspace_id // ""),
        (.result.source.source_checkout_path // .result.source.repo_root // ""),
        ($entry.path // "")]
    | join("\u001f")' <<<"$listing")
  IFS=$separator read -r found open_id source_id source_path path <<<"$fields"
  if [ -z "$found" ]; then
    notify "open worktree" "That worktree no longer exists."
    return 0
  fi

  if [ -n "$open_id" ]; then
    output=$("$herdr" workspace focus "$open_id" 2>&1 >/dev/null) || notify_error "open worktree" "$output"
    return 0
  fi

  # Open from the repo's parent workspace. When that is closed, point Herdr at
  # the parent checkout and it reopens the group around it.
  if [ -n "$source_id" ]; then
    set -- --workspace "$source_id"
  else
    set -- --cwd "$source_path"
  fi
  output=$("$herdr" worktree open "$@" --path "$path" --focus 2>&1 >/dev/null) ||
    notify_error "open worktree" "$output"
}

case ${1:-} in
  workspace) pick_workspace ;;
  agent) pick_agent ;;
  join-pane) pick_join_pane ;;
  worktree) pick_worktree ;;
  _refresh-worktree) refresh_worktrees "$2" "${3:-0}" ;;
  *)
    printf 'usage: %s workspace|agent|join-pane|worktree\n' "${0##*/}" >&2
    exit 2
    ;;
esac

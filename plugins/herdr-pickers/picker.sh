#!/usr/bin/env bash
# fzf pickers styled like Herdr's built-in overlays. Herdr runs each one in a
# titled popup (see herdr-plugin.toml), so the popup border carries the title.
#
# The colors are ANSI indices that mirror Herdr's "terminal" theme, so the
# pickers follow the active tinty scheme the same way Herdr's own UI does.

set -euo pipefail

herdr=${HERDR_BIN_PATH:-}
[ -n "$herdr" ] || herdr=herdr
context=${HERDR_PLUGIN_CONTEXT_JSON:-}
[ -n "$context" ] || context='{}'
tab=$'\t'

# Shared jq helpers: ~-relative paths and "1 tab"/"2 tabs".
jq_defs='
def tilde: (env.HOME // "") as $home
  | if $home != "" and startswith($home) then "~" + .[($home | length):] else . end;
def count(n; noun): "\(n) \(noun)\(if n == 1 then "" else "s" end)";
'

# Renders {key, label, detail, status} objects as NUL-separated fzf items. Each
# item is two lines like Herdr's worktree picker: a bold label with the status
# right-aligned, then the detail underneath. Widths count emoji and CJK as two
# cells so the status column stays aligned.
render_items='
def field: (. // "") | tostring | gsub("[\t\n\r]"; " ");
def cells: explode | map(
  if . == 8205 or (. >= 768 and . <= 879) or (. >= 65024 and . <= 65039) then 0
  elif (. >= 4352 and . <= 4447) or (. >= 11904 and . <= 42191)
    or (. >= 44032 and . <= 55203) or (. >= 63744 and . <= 64255)
    or (. >= 65072 and . <= 65103) or (. >= 65280 and . <= 65376)
    or (. >= 65504 and . <= 65510) or (. >= 127744 and . <= 129791)
    or (. >= 131072 and . <= 262141) then 2
  else 1 end) | add // 0;
(.label | field) as $label | (.status | field) as $status
# One column each for the leading space, trailing space, and scrollbar.
| ([$cols - 3 - ($label | cells) - ($status | cells), 1] | max) as $pad
| "\(.key | field)\t\u001b[1m \($label)\u001b[22m\(" " * $pad)\($status)\n \(.detail | field)\u0000"
'

columns() {
  local size cols=${HERDR_PICKER_COLUMNS:-}
  if [ -z "$cols" ]; then
    size=$(stty size </dev/tty 2>/dev/null || true)
    cols=${size#* }
  fi
  case $cols in '' | *[!0-9]*) cols=80 ;; esac
  printf '%s\n' "$cols"
}

# Reads rendered-item objects on stdin and prints the chosen key.
pick() {
  local noun=$1 placeholder=$2 action=$3 cols primary cancel left footer info
  cols=$(columns)

  primary=" ↵ $action "
  cancel=" esc cancel "
  left=$(((cols - ${#primary} - 2 - ${#cancel}) / 2))
  ((left > 0)) || left=0
  printf -v footer '%*s\033[1;90;44m%s\033[0m  \033[1m%s\033[0m' "$left" "" "$primary" "$cancel"

  # shellcheck disable=SC2016 # Expanded by fzf's info command, not here.
  info='n=$FZF_MATCH_COUNT t=$FZF_TOTAL_COUNT w=$HERDR_PICKER_NOUN
[ "$t" = 1 ] || w="${w}s"
if [ "$n" = "$t" ]; then printf "%s %s " "$t" "$w"; else printf "%s/%s %s " "$n" "$t" "$w"; fi'

  jq -j --argjson cols "$cols" "$render_items" |
    HERDR_PICKER_NOUN=$noun FZF_DEFAULT_OPTS="" FZF_DEFAULT_OPTS_FILE="" fzf \
      --read0 --ansi --layout=reverse --no-sort \
      --delimiter="$tab" --with-nth=2.. --accept-nth=1 \
      --highlight-line --pointer='' --marker='' --scrollbar='│' \
      --prompt=' / ' --ghost="$placeholder" \
      --info=inline-right --info-command="$info" \
      --footer="$footer" --footer-border=none \
      --color='fg:-1,bg:-1,fg+:8:regular,bg+:4,gutter:-1,hl:4:regular,hl+:0:underline' \
      --color='prompt:7:regular,query:-1:regular,ghost:7,info:7,separator:8,scrollbar:8' \
      --color='header:-1,footer:-1,pointer:8,marker:8,spinner:4' || true
}

pick_workspace() {
  local selected
  selected=$("$herdr" workspace list | jq -c "$jq_defs"'
    .result.workspaces[]
    | {
        key: .workspace_id,
        label,
        detail: ([count(.tab_count; "tab"), count(.pane_count; "pane")]
          + (if .worktree.checkout_path then [.worktree.checkout_path | tilde] else [] end)
          | join(" · ")),
        status: ([if .focused then "current" else empty end,
          if .agent_status == "unknown" then empty else .agent_status end] | join(" · "))
      }' | pick workspace "filter workspaces" switch)
  [ -z "$selected" ] || "$herdr" workspace focus "$selected" >/dev/null
}

pick_agent() {
  local workspaces tabs agents selected
  workspaces=$("$herdr" workspace list)
  tabs=$("$herdr" tab list)
  agents=$("$herdr" agent list)
  selected=$(jq -cn --argjson workspaces "$workspaces" --argjson tabs "$tabs" --argjson agents "$agents" "$jq_defs"'
    ($workspaces.result.workspaces | map({key: .workspace_id, value: .label}) | from_entries) as $workspace
    | ($tabs.result.tabs | map({key: .tab_id, value: .label}) | from_entries) as $tab
    | $agents.result.agents[]
    | {
        key: .pane_id,
        label: ($tab[.tab_id] // .tab_id),
        detail: ([$workspace[.workspace_id] // .workspace_id,
          ((.terminal_title_stripped // "") | if . == "" then empty else . end)
            // (.cwd // "" | tilde)] | join(" · ")),
        status: ([if .focused then "current" else empty end, .agent,
          if .agent_status == "unknown" then empty else .agent_status end] | join(" · "))
      }' | pick agent "filter agents" switch)
  # Herdr 0.9.0's agent focus updates server state without moving the attached
  # client's viewport (herdrdev/herdr#3760). The raw pane.focus method still
  # projects to the client and also selects the exact pane in a split tab.
  [ -z "$selected" ] || "$HOME/.local/bin/herdr-focus-pane" "$selected" >/dev/null
}

pick_join_pane() {
  local workspace_id tab_id panes tabs selected
  workspace_id=$(jq -r '.workspace_id // empty' <<<"$context")
  tab_id=$(jq -r '.tab_id // empty' <<<"$context")
  [ -n "$workspace_id" ] && [ -n "$tab_id" ] || return 0
  panes=$("$herdr" pane list)
  tabs=$("$herdr" tab list --workspace "$workspace_id")
  selected=$(jq -cn --argjson panes "$panes" --argjson tabs "$tabs" --arg workspace "$workspace_id" --arg current_tab "$tab_id" "$jq_defs"'
    ($tabs.result.tabs | map({key: .tab_id, value: .label}) | from_entries) as $tab
    | $panes.result.panes[]
    | select(.workspace_id == $workspace and .tab_id != $current_tab)
    | {
        key: .pane_id,
        label: ($tab[.tab_id] // .tab_id),
        detail: (.foreground_cwd // .cwd // "" | tilde),
        status: (if .agent then
          [.agent, if .agent_status == "unknown" then empty else .agent_status end] | join(" · ")
        else "shell" end)
      }' | pick pane "filter panes" join)
  [ -z "$selected" ] || "$herdr" pane move "$selected" --tab "$tab_id" --split right --focus >/dev/null
}

case ${1:-} in
  workspace) pick_workspace ;;
  agent) pick_agent ;;
  join-pane) pick_join_pane ;;
  *)
    printf 'usage: %s workspace|agent|join-pane\n' "${0##*/}" >&2
    exit 2
    ;;
esac

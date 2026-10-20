---
# Managed by dotfiles: home/pi-agent/agents/work/implementer.md
# Work machines only. A pinned model keeps the bundled noExtensions policy, so
# load the Shopify AI proxy that supplies the anthropic provider explicitly.
# Herdsman caps a managed agent's bash call without a timeout, so long jobs
# need a background runner. Without one, implementers polled with sleep: 103
# calls and 330 minutes in 30 days. background-jobs adds bg_run and bg_wait.
# The bundled body replaces Pi's system prompt, which drops its edit-tool
# rules. Implementers then made 180 edits through bash and 54 with edit/write.
# shell-guard (pi-extensions) enforces both rules: it blocks sleep polling and
# bash edits of tracked files, and blocks destructive git and pkill commands.
name: implementer
model: anthropic/claude-sonnet-5-5
thinking: medium
extensions: ["~/.pi/agent/extensions/shopify-proxy", "~/.pi/agent/extensions/background-jobs", "~/.pi/agent/git/github.com/teddyhwang/pi-extensions/extensions/shell-guard/index.ts"]
tools: ["read", "bash", "edit", "write", "bg_run", "bg_wait", "bg_log", "bg_stop", "bg_list"]
bodyMode: append
---

## Long-running commands

If a command can run for more than a few minutes, start it with bg_run. Then
call bg_wait with a timeout that is longer than the expected run time. Do not
poll with sleep in bash. Use bg_log with offset to read only new output.

## File changes

Change files with edit, and create files with write. Do not change source
files with sed -i, heredocs, or scripts that replace text.

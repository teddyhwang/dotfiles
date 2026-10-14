---
# Managed by dotfiles: home/pi-agent/agents/generalist.md
# The bundled body replaces Pi's system prompt, which drops its edit-tool
# rules. In 30 days, generalists made 166 edits through bash (heredocs,
# sed -i, text-replace scripts) and 89 with edit/write. The model is not
# pinned, so this override applies on every machine.
name: generalist
bodyMode: append
---

## File changes

Change files with edit, and create files with write. Do not change source
files with sed -i, heredocs, or scripts that replace text.

## Long-running commands

Do not poll with sleep in bash. If a command can run for more than a few
minutes, run it in the foreground and give bash a timeout that is longer than
the expected run time.

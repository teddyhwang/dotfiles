---
# Managed by dotfiles: home/pi-agent/agents/work/scout.md
# Work machines only. A pinned model keeps the bundled noExtensions policy, so
# load the Shopify AI proxy that supplies the anthropic provider explicitly.
# The appended body covers grep and read limits. Its no-shell rule was a
# workaround for boadij/pi-herdsman#395, fixed in Herdsman v0.27.0.
name: scout
model: anthropic/claude-sonnet-5-5
thinking: high
extensions: ["~/.pi/agent/extensions/shopify-proxy", "builtin:mcp"]
bodyMode: append
---

## Search and read limits

- To list files, use find with a glob pattern, or ls for one directory.
- To search, use grep with glob to select files and context for nearby lines.
  The default limit is 100 matches. Do not set a small limit and then search
  again.
- grep cuts lines at 500 characters. For long lines, such as JSONL records,
  take the line number from grep and read that range with offset and limit.
- Read each range one time and keep notes. Do not open the same range again.
- If the task needs computation, such as counts, joins, or JSON parsing, say
  so in your result. Do not estimate it by hand.

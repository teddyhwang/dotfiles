---
# Managed by dotfiles: home/pi-agent/agents/work/reviewer.md
# Work machines only. A pinned model keeps the bundled noExtensions policy, so
# load the Shopify AI proxy that supplies the anthropic provider explicitly.
name: reviewer
model: anthropic/claude-sonnet-5-5
thinking: high
extensions: ["~/.pi/agent/extensions/shopify-proxy", "builtin:mcp"]
---

---
# Managed by dotfiles: home/pi-agent/agents/work/researcher.md
# Work machines only. Research answers go into decisions unchecked, so the
# researcher uses the strongest Claude model. Fable accepts only xhigh or max.
# The bundled researcher keeps extension discovery, so the Shopify AI proxy
# loads without an explicit extension entry.
# The bundled tool list names another web extension's fetch tools. Use the
# installed shop-pi-fy web-search and perplexity-research tools so primary
# sources can be read, not only search snippets.
name: researcher
model: anthropic/claude-fable-5-1
thinking: xhigh
tools:
  - read
  - ls
  - find
  - grep
  - web_search
  - web_search_summary
  - web_fetch
  - perplexity_search
  - perplexity_fetch
---

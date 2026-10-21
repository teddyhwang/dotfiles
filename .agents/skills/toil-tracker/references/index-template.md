# Index template

Setup copies the first block below to `index.md` when no journal exists. It
never writes over an existing index.

```markdown
# Toil Journal

Avoidable friction hit by coding agents, ranked by how often it happens × what it costs. The toil-tracker skill explains how to use this journal.

- **Budget:** 32768 UTF-8 bytes
- **Issues:** draft them in `drafts/`
- **Docs and instructions:** draft changes in `drafts/`
- **Fixes outside the current task:** draft a patch or plan in `drafts/`

## Entries
```

## Changing the rules

Edit the header lines to grant more. For example:

- `**Issues:** file directly in {tracker}`
- `**Docs and instructions:** edit {files} directly`
- `**Fixes outside the current task:** fix directly in {repository}`

Index lines go directly under `## Entries`, newest last:

```markdown
- [Test runner exits 0 when a suite fails to load](2026-01-15-test-runner-exit-0.md) ×2 · open
```

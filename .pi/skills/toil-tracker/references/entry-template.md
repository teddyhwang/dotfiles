# Problem file template

Name the file `YYYY-MM-DD-short-name.md`, using the date of the first
occurrence. Keep the field names so they are easy to search. Use paths
relative to the journal directory, so links still work after the file moves
into `archive/`.

```markdown
## {What went wrong, in a few words}

- **Status:** open
- **Hits:** 1
- **First seen:** {YYYY-MM-DD}
- **Total cost:** {for example 6 tool calls, ~20 min}
- **Kind:** {loud failure | wrong output without an error}
- **Cause:** {what actually went wrong, or "unknown"}
- **Smallest fix:** {the change that would prevent it}
- **Links:** {issue, draft, commit or doc}

### Occurrences

1. {YYYY-MM-DD} · {cost} · {what you were doing} · {exact error, command or wrong output}
```

## Status values

Open: `open`, `reopened`, `watching`, `waiting for index space`.
Closed: `fixed`, `documented`, `filed`, `drafted`.

## Adding an occurrence

Append the next numbered occurrence, add one to **Hits**, add its cost to
**Total cost**, and update **Cause** or **Smallest fix** if you learned more.
Update the `×hits` count on the index line. Don't edit earlier occurrences.

## Drafts

Put drafts in `drafts/`, named after the problem file with `-issue`, `-fix`
or `-doc` added, for example `drafts/2026-01-15-flaky-test-issue.md`. Start
the draft with the problem file's name and keep its evidence at the end.

## Closing

```markdown
### Closed

{YYYY-MM-DD} · {fixed | documented | filed | drafted} · {link or path}
```

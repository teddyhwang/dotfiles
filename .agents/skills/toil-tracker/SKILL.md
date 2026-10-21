---
name: toil-tracker
description: "Keep a running log of avoidable friction that coding agents hit: retries, dead ends, misleading tool output, stale docs. Records each problem once, counts repeats, ranks by how often it happens and what it costs, and turns the worst ones into fixes or drafts for a human to review. Load after a task hit avoidable friction, before editing the toil journal, or when asked to set toil tracking up."
---

# Toil Tracker

Some work takes longer than it should because a tool, document, script or
environment got in the way. This skill keeps a small journal of that friction
so repeated problems become visible and get fixed instead of rediscovered.

Do it quietly. Don't pause a task to ask whether something deserves a note:
record it, act if you are allowed to, and mention it in your final summary.

## Where the journal lives

The always-on instruction line that pointed you here names the journal's
`index.md`. Everything sits in that directory:

- `index.md`: a header with the rules for this journal, then one line per open
  problem.
- `YYYY-MM-DD-short-name.md`: one file per problem, beside the index.
- `archive/`: problem files that are closed.
- `drafts/`: issues, patches or doc changes written for a human to review.

Create `archive/` and `drafts/` the first time you need them. If the index
doesn't exist, the journal isn't set up: mention the friction in one line of
your summary and stop. [references/setup.md](references/setup.md) explains
how to set it up when the user asks.

## What counts

Count it when something outside your own reasoning cost real effort:

- a command or tool that failed, hung or needed several retries;
- an error message that pointed at the wrong cause;
- output that looked correct but wasn't;
- documentation or instructions that were wrong, missing or out of date;
- a setup step that had to be worked around.

Ordinary exploration, reading unfamiliar code and fixing your own one-off
mistake don't count.

## Recording a problem

1. Read `index.md`. Open any problem file whose line looks related.
2. If one describes the same root cause, even from a different task, add an
   occurrence to it: raise its hit count, add the date, cost and evidence, and
   update its index line. Never create a second file for the same cause.
3. If nothing open matches, look through `archive/`. If a closed problem
   matches and it was closed as fixed or documented, the fix didn't work: move
   it back next to the index, set its status to `reopened`, and give it an
   index line again. If it was closed as drafted or filed, add the occurrence
   to the archived file (and to its draft in `drafts/`) and mention it in your
   summary.
4. Otherwise create a new file from
   [references/entry-template.md](references/entry-template.md) and add one
   index line:

   ```markdown
   - [What went wrong](2026-01-15-short-name.md) ×1 · open
   ```

Write measured costs (tool calls, minutes, wrong results produced), not
adjectives. Remove secrets, tokens and personal data from evidence. Re-read a
file just before editing it, since a human may have changed it.

## Deciding what to do

Rank problems by **how often they happen × what they cost**. A problem that
gives wrong output without an error ranks above a loud failure of the same
size, because it also makes other results harder to trust.

The index header says what you may do on your own. Anything it doesn't allow,
write as a draft in `drafts/` instead. Then pick the first action that fits:

1. **Fix it now** if the fix is small and part of the task you were given.
   A new problem fixed this way needs no journal entry.
2. **Fix it separately** if the cause is clear and the fix is small, safe and
   independent of your task, and the header allows separate fixes. Otherwise
   draft the patch or a plan.
3. **Report it** (issue or draft) once it has happened twice, or once if it
   produced wrong output without an error.
4. **Correct the docs or instructions** if the problem is guidance rather
   than code, directly where the header allows it, otherwise as a draft.
5. **Leave it in the journal** if none of the above applies yet.

If the user asked to watch a problem without changing it, set its status to
`watching`: keep adding occurrences, but take no action on it.

## Closing a problem

A problem is closed once it is fixed, documented, filed as an issue or
drafted in `drafts/`. In one pass:

1. Set its status to the outcome and add a `### Closed` note with the date and
   a link or path.
2. Move the file into `archive/` unchanged (add `-2`, `-3` if the name is
   taken).
3. Remove its line from `index.md`.

Never delete problem files or occurrences.

## Keeping the index small

`index.md` has a size limit in its header (32768 bytes by default; check with
`wc -c`). Before an edit would pass it, shorten the longest index lines, then
close any problems that already have a fix, issue or draft. If it still
doesn't fit, record the occurrence in the problem file only, set a new
problem's status to `waiting for index space`, and tell the user the index is
full. Add the waiting lines back, oldest first, once there is room.

## Summary

At the end of the task, say briefly what cost time, why, and the smallest
change that would prevent it, plus what you recorded, fixed or drafted and
anything that needs the user's decision. Don't repeat problems that are
already tracked and unchanged.

This skill doesn't grant any permissions. Changes outside the journal still
follow the user's instructions and the host's rules.

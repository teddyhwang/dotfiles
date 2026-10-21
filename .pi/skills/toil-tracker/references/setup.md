# Setting up toil tracking

Only do this when the user asks. Running it again on a working setup should
change nothing.

## 1. Look for an existing setup

- Search the agent instruction files that load in every session (for example
  `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, at user and project level) for a
  line that mentions `toil-tracker`.
- Look for an `index.md` whose first heading is `# Toil Journal`.

If you find exactly one instruction line and the journal it names, setup is
done: say so and stop. If you find more than one of either, or a line whose
journal is missing, change nothing and ask the user which to keep.

## 2. Choose where it goes

Ask the user, if they haven't said:

- **Everywhere:** the line goes in the user-level instruction file and the
  journal in a user-level directory such as `~/toil`.
- **One project:** the line goes in that project's instruction file and the
  journal in the project, for example `toil/`. If that file is committed and
  shared, the line affects everyone's agents; check first.

## 3. Create the journal

Create the directory and copy the first block from
[index-template.md](index-template.md) into `index.md`. Leave the header's
defaults (everything is drafted) unless the user grants more. Don't create
`archive/` or `drafts/` yet.

## 4. Add the instruction line

Append one line to the chosen instruction file, filling in both paths:

```markdown
- Toil Tracker: when a task hits avoidable friction (retries, dead ends, misleading output, wrong docs), load the toil-tracker skill ({skill path}/SKILL.md), record it in {journal}/index.md, and say what you recorded, fixed or drafted in your summary.
```

Use `~/` or project-relative paths, never an absolute path with a username.

## 5. Check and report

Confirm that `index.md` exists and is under its size limit, that exactly one
instruction line exists, and that its skill path resolves. Tell the user
where the journal is and how to grant more permissions in its header.

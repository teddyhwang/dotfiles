# Global rules for Pi

Managed by dotfiles: `home/pi-agent/AGENTS.md`, linked to
`~/.pi/agent/AGENTS.md`. These rules apply in every working directory.

Only the pi-extensions package is installed on every machine. Tools from other
packages, and the agents and CLIs named below, can be missing. A rule that
names one of them applies only when it is available. Otherwise use the
fallback in the same rule, or say what is missing.

## File changes

- Change part of an existing file with `edit`. Replace a whole file or create a
  file with `write`.
- Do not change files with `sed -i`, `perl -i`, heredoc or `echo` redirects, or
  scripts that read, replace, and write text. These fail several times more
  often than `edit`. shell-guard blocks them for files that git tracks.

## Waiting

- Do not poll with `sleep N; check`. Each check costs a full model turn, and
  shell-guard blocks it if `bg_wait` is available.
- If `bg_run` and `bg_wait` are available, start long jobs with `bg_run`. Then
  call `bg_wait` with a timeout of at most 10 minutes. If the job is still
  running, give one line of progress from `bg_log` and wait again.
- Before a call that can block for more than about 2 minutes (a wait, an
  `until` loop, a slow build, test or log query), tell the user in one line
  what you wait for and how long you expect it to take.
- If they are not available, wait in one call, for example
  `until <check>; do sleep 10; done`, and give bash a timeout that is longer
  than the expected wait.

## Batching

- When calls do not depend on each other, make them in the same turn as
  parallel tool calls. If `codemode` is available, use one script for more than
  about four calls, or when the output needs filtering.
- Never put a call that reads, views, or uses a file in the same parallel
  batch as the call that creates or changes it. Wait for the producer to
  finish successfully before starting the consumer. If `codemode` is available,
  chain dependent calls with `await`; otherwise use successive tool calls.
- If Herdsman agents are available, send broad codebase exploration to a
  `scout` agent.

## Links

- If you use `web_fetch` or another fetch tool, it cannot read pages behind a
  login: it gets an SSO page or a 401. Use the tool for that site, or ask the
  user for the content.
- Google Docs (`docs.google.com`): if a Google Docs tool is available, use it.
  Otherwise ask the user for an export or for the text.

## Agent Delegation

- If Herdsman or Rex agents are available, delegate bounded work to specialists:
  **scout** (read-only exploration), **implementer** (approved changes),
  **reviewer** (independent assessment), **researcher** (external facts).
- Give each agent: specific goal, file paths, acceptance criteria, and explicit
  authority (can commit, can deploy, read-only, etc.).
- **You own coordination:** Allocate exclusive worktrees to writers; enforce
  producer-before-consumer sequencing; limit concurrent heavy tests; verify
  dependencies and access before delegating.
- **Integration and deployment:** Name the owner for root/submodule builds,
  activation consent, and post-deploy checks. Distinguish "implemented" from
  "deployed and accepted."
- **Acceptance:** For browser/UI work, require live verification evidence
  (screenshots, terminal output) before accepting "done."
- Track blocked agents and coordination failures in ~/toil/index.md.

## Toil

- Toil Tracker: when a task hits avoidable friction (retries, dead ends,
  misleading output, wrong docs), load the toil-tracker skill
  (~/.agents/skills/toil-tracker/SKILL.md), record it in ~/toil/index.md, and
  say what you recorded, fixed or drafted in your summary.

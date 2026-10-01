# Repository instructions

- After making a fix in this repository, run `./scripts/check.sh`.
- If the checks pass, commit the completed fix and push the current branch to its upstream remote.
- Do not leave a completed fix uncommitted or unpushed unless the user explicitly asks you to.

## Pi extension ownership

- The canonical repository for personal Pi extensions is https://github.com/teddyhwang/pi-extensions, installed as a Pi package.
- Implement Pi extension features, fixes, and their regression tests in that repository—not in dotfiles, `home/pi-agent/extensions`, or ad-hoc `~/.pi/agent/extensions` copies.
- Dotfiles owns Pi configuration and installation/integration wiring only. Do not create a second source of truth or edit the installed CLI's generated files as a durable fix.
- Leave third-party extensions managed by their own installers alone. Remove legacy personal copies only after verifying that the canonical package supplies them and that the copies or symlinks are ours.
- If a task changes both repositories, validate, commit, and push each repository separately. `tests/pi-extension-boundary.test.mjs` enforces this repository's configuration-only boundary.

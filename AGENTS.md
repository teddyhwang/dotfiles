# Repository instructions

- After making a fix in this repository, run `./scripts/check.sh`.
- If the checks pass, commit the completed fix and push the current branch to its upstream remote.
- Do not leave a completed fix uncommitted or unpushed unless the user explicitly asks you to.

## Languages

This repository uses two languages for its own code. Do not add another one.

- **Shell** for bootstrap, installers, linkers and small wrappers. Use POSIX `sh` when you can and `bash` when you need it. Zsh is only for Zsh configuration.
- **Node** (built-in modules only, Node 24, ESM) for code that needs data structures, JSON, sockets or tests. Use `.mjs` in `scripts/` and `tests/`. Executables in `home/local/bin` keep a name with no extension and start with `#!/usr/bin/env node`.
- Do not add Python, Ruby, Perl, Go or any other language, including one-line `python3 -c` helpers inside shell scripts, tests or JSON configuration. If Node or shell cannot do the job, ask the user first.
- Do not add npm dependencies or a `package.json`. For TOML, YAML or plists, call a command-line tool that `check.sh` requires (`taplo`, `yq`, `plutil`). Tests can use `tests/helpers/toml.mjs` and `tests/helpers/yaml.mjs`.
- Node is installed by the package step. Code that runs before `scripts/packages_mac.sh` or `scripts/packages_linux.sh` (`bootstrap.sh`, `setup.sh` up to the package step, `scripts/verify_dependencies.sh`, `scripts/brew.sh`) must be POSIX `sh`. A shell script that calls Node must stop with a clear error when `node` is missing.
- The exceptions are languages that an application requires for its configuration: Lua (Neovim, Hammerspoon, WezTerm, Hyprland), QML and JavaScript (Omarchy plugins, Amethyst layouts, opensessions), and `awk` programs called from shell. To call macOS frameworks, use JavaScript for Automation (`osascript -l JavaScript`), not AppleScript or Swift.
- `tests/language-policy.test.mjs` enforces these rules.

## Pi extension ownership

- The canonical repository for personal Pi extensions is https://github.com/teddyhwang/pi-extensions, installed as a Pi package.
- Implement Pi extension features, fixes, and their regression tests in that repository—not in dotfiles, `home/pi-agent/extensions`, or ad-hoc `~/.pi/agent/extensions` copies.
- Dotfiles owns Pi configuration and installation/integration wiring only. Do not create a second source of truth or edit the installed CLI's generated files as a durable fix.
- Leave third-party extensions managed by their own installers alone. Remove legacy personal copies only after verifying that the canonical package supplies them and that the copies or symlinks are ours.
- If a task changes both repositories, validate, commit, and push each repository separately. `tests/pi-extension-boundary.test.mjs` enforces this repository's configuration-only boundary.

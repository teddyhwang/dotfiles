# Dotfiles

Personal macOS and Arch/Omarchy configuration for Bash, Zsh, Neovim, Herdr,
tmux, terminal emulators, and desktop tools.

## Install

```sh
git clone git@github.com:teddyhwang/dotfiles.git ~/src/github.com/teddyhwang/dotfiles
cd ~/src/github.com/teddyhwang/dotfiles
./setup.sh
```

The setup is idempotent and can be run from any working directory. Existing
files are kept unless replacement is confirmed; confirmed replacements are
moved to `~/.local/state/dotfiles/backups/replaced.*/` rather than deleted.
Targets with traversal segments or parents resolving outside HOME are refused.
On macOS, setup uses `Brewfile.work` when `devx` is available as a command;
otherwise it uses the personal `Brewfile`. Missing dependencies are installed
with `--no-upgrade`; workstation-wide upgrades are intentionally left as a
separate maintenance action.

### Supported systems

- **macOS:** Homebrew packages, app configuration, launch agents, and shared
  shell/editor configuration.
- **Arch/Omarchy Linux:** `pacman`/`yay` packages, Hyprland, keyd, Omarchy, and
  shared shell/editor configuration. ShellCheck already available on `PATH`
  (for example, through Neovim's Mason) is reused instead of installing its
  pacman package.

Linux T2 suspend support requires an explicit privileged run after the normal
user setup. The same step keeps a closed laptop awake on external power even
when an EDID-less KVM briefly drops its display connection:

```sh
sudo ./scripts/macbook_t2_linux.sh
```

## Validate

```sh
./scripts/check.sh
```

This runs shell syntax checks, ShellCheck, structured-config parsing, Python and
Lua compilation checks when available, and the Node test suite. GitHub Actions
runs the same check on Linux and macOS. Validation needs Node 24+, Python 3.11+,
Ruby with `YAML.safe_load_file`, jq, ShellCheck, Bash, and Zsh. Neovim and tmux enable
additional isolated integration tests.

Measure warm startup locally (no cache deletion or dependency installation):

```sh
python3 scripts/benchmark.py --runs 21
```

This measures startup plus immediate exit, without a TTY. It does not measure
first-prompt readiness, deferred plugins, or LSP initialization.

## Maintenance

`Brewfile` is the curated personal package list. `Brewfile.work` is a
generated snapshot of everything installed through Homebrew on the work Mac.
During `setup.sh`, an available `devx` command selects `Brewfile.work`; without
`devx`, setup selects `Brewfile`. Refreshing the snapshot never changes the
personal file.

```sh
# Refresh the work Mac snapshot from the current machine
./scripts/backup_brewfile.sh

# Restore the generated snapshot on another Mac
brew bundle install --file ./Brewfile.work

# Install anything newly added to the personal Brewfile without upgrading everything
brew bundle install --no-upgrade --file ./Brewfile

# Deliberately upgrade managed personal Homebrew dependencies
brew bundle upgrade --file ./Brewfile

# Start heavyweight development services only when needed
brew services start postgresql@14 # or mysql@8.4, redis, ollama

# Update Neovim plugins (lazy-lock.json stays local to this machine)
nvim '+Lazy update'
```

The backup script records taps, formulae, casks, and any Mac App Store entries
that Homebrew Bundle can detect. It excludes VS Code extensions and global Go,
Cargo, uv, and npm packages so `Brewfile.work` remains a Homebrew inventory.
The snapshot is generated without package-description comments to keep updates
easy to review in Git.

macOS launch-agent setup is separate from package installation and runs after
binaries are linked. Re-running `scripts/services_mac.sh` also repairs unloaded
managed jobs. Clipboard agents remain opt-in. tmux plugin installation uses a
private, sessionless server and checks every declared plugin without touching
your active tmux sessions.

Database servers and Ollama are installed but deliberately not enabled at
login by this setup. Previously enabled services are not stopped automatically.
`home/config/nvim/lazy-lock.json` is machine-local and ignored by Git. Herdr setup
uses its `herdr-splits.nvim` revision when present, or a pinned fallback from
`scripts/herdr.sh` before Neovim has installed the plugin. Neovim's Herdr plugin
also synchronizes the Herdr side when it builds or loads inside Herdr.

### Superfile theme

Superfile (`spf`) uses our custom `seti` theme in
`home/config/superfile/theme/seti.toml`, matching tinty's `base16-seti` palette.
It uses charcoal backgrounds, blue active borders, green selections/success,
and red errors. The theme is selected with `theme = 'seti'` in
`home/config/superfile/config.toml`.

[Custom themes](https://superfile.dev/configure/custom-theme/) are ordinary TOML
files under `~/.config/superfile/theme/`; the config selects the filename without
`.toml`. They control panels, borders, selections, dialogs, and status colors.
Restart `spf` after editing a theme. Seti is a fixed palette, not a tinty hook:
changing tinty's scheme does not change Superfile's UI theme.

Code previews use `code_previewer = 'bat'` and our existing
`home/config/bat/config` (`base16-256`) to follow the terminal's palette. This
requires `bat`, already included in our setup. Superfile's built-in Chroma
highlighter has no Seti style; if you switch back to `code_previewer = ''`, the
theme selects `base16-snazzy` as a non-Seti alternative.

### Superfile hotkeys

Superfile uses the complete upstream Vim-like preset in
`home/config/superfile/hotkeys.toml`, copied unchanged from
[`vimHotkeys.toml` at v1.6.0](https://github.com/yorukot/superfile/blob/v1.6.0/src/superfile_config/vimHotkeys.toml).
Setup links `home/config/superfile` to `~/.config/superfile`, so no shell alias or
extra launch flag is needed. Restart Superfile after changing the file.

Superfile v1.6.0 has no built-in Vim preset selector: its
[documented configuration](https://superfile.dev/configure/custom-hotkeys/) uses a
hotkeys file. Removing ours would restore the standard defaults, not Vim keys;
`--hotkey-file` only selects an alternate file. When updating the preset, copy
`src/superfile_config/vimHotkeys.toml` from the matching upstream release over
our `hotkeys.toml` and update the source version above.

Key bindings include `q` to close a file panel, `Ctrl+C` to quit, `f` to toggle
the preview, `-` to go to the parent directory, and `m` to toggle selection mode.

### Pi extensions

Personal Pi extension code and tests live in
[`teddyhwang/pi-extensions`](https://github.com/teddyhwang/pi-extensions),
installed with `pi install git:git@github.com:teddyhwang/pi-extensions`.
This repository manages Pi configuration and integration wiring only; do not
add extension implementations here or maintain separate personal copies in
`~/.pi/agent/extensions`. After package changes, use `/reload` in active sessions.

The former dotfiles `session-tab-name` extension now belongs to that package.
Setup removes only its exact old dotfiles symlink, preserving third-party
extensions and user-maintained files. See `AGENTS.md` for the ownership guardrail.

Herdsman role overlays live in `home/pi-agent/agents/` and are linked individually
so other user/installer definitions remain intact. The researcher overlay loads
only `pi-perplexity` and exposes its actual `perplexity_search` tool, alongside
read-only filesystem tools; it does not load every personal extension's handlers.

For Pi 1.0, the currently validated Herdsman revision is pinned rather than
following moving `main` (the numbered npm release still targets an older Pi):

```sh
pi install git:github.com/boadij/pi-herdsman@382a18800198b082730d89cd4132d38d25b5d669
cd ~/.pi/agent/git/github.com/boadij/pi-herdsman
npm ci --ignore-scripts
npm run build
npm run check
npm run package:audit
# Only after the candidate builds and validates:
pi remove npm:pi-herdsman
```

Git installs need the upstream build because the package's runtime entrypoint is
`dist/index.js`. Do not reload while both sources are enabled or managed work is
unresolved. Reload after the old source is removed. This revision targets Pi
1.0.0, supports Herdr >=0.9.1, and was tested upstream with Herdr 0.9.3; it does
not require restarting or downgrading the current Herdr server. Do not run the
release bootstrap as a substitute: it installs the runtime tuple declared by
the older published release. Keep agent-teams enabled until its separate task,
budget, and write-scope requirements have been explicitly migrated.

Generated theme files, caches, machine-local configuration, and secret-bearing
environment files are ignored. Never add credentials to the repository; use the
system keychain, 1Password, or untracked local environment files instead.

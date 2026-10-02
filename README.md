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

Superfile uses a customized Vim-like preset in
`home/config/superfile/hotkeys.toml`, based on upstream
[`vimHotkeys.toml` at v1.6.0](https://github.com/yorukot/superfile/blob/v1.6.0/src/superfile_config/vimHotkeys.toml).
Setup links `home/config/superfile` to `~/.config/superfile`, so no shell alias or
extra launch flag is needed. Restart Superfile after changing the file.

Superfile v1.6.0 has no built-in Vim preset selector: its
[documented configuration](https://superfile.dev/configure/custom-hotkeys/) uses a
hotkeys file. Removing ours would restore the standard defaults, not Vim keys;
`--hotkey-file` only selects an alternate file. When updating the preset, use
`src/superfile_config/vimHotkeys.toml` from the matching upstream release,
retain our navigation customizations below, and update the source version above.

`h` and Backspace go to the parent directory; `l` or Enter opens the selected
folder/file. Uppercase `H`/`L` move to the previous/next file pane (left/right);
Shift+Tab/Tab still work too. While typing in a prompt, `h`/`l`/`H`/`L` remain
text, Backspace deletes text, and only Enter confirms. Other bindings include
`j`/`k` to move down/up, `q` to close a file panel, `Ctrl+C` to quit, `f` to toggle
the preview, and `m` to toggle selection mode.

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

[Pi Herdsman](https://github.com/boadij/pi-herdsman) is installed from a local
clone of `main`. The npm release targets an older Pi. A git install has no
built `dist/index.js`, and its dependency install fails when the package proxy
does not serve the Pi 1.0.0 packages.

```sh
git clone https://github.com/boadij/pi-herdsman ~/src/github.com/boadij/pi-herdsman
cd ~/src/github.com/boadij/pi-herdsman
# Install only esbuild, outside the clone, so no copy of Pi's own packages
# lands in node_modules.
npm install --prefix ~/.cache/pi-herdsman-build esbuild@0.28.2
mkdir -p node_modules
ln -sfn ~/.cache/pi-herdsman-build/node_modules/esbuild node_modules/esbuild
node scripts/build.mjs
pi install ~/src/github.com/boadij/pi-herdsman
herdr integration install pi
```

To update, run `git pull && node scripts/build.mjs` in the clone, then `/reload`.
`pi update` does not update local packages. Do not use the upstream `install.sh`:
it installs the runtime of the older npm release.

Herdsman's strict tool schemas exceed Anthropic's compiled-grammar limit, so
`home/pi-agent/models.json` turns off strict tools for the `anthropic` provider.

Herdsman replaces agent-teams. Disable agent-teams with the package filter
`-extensions/agent-teams/index.ts` on the pi-extensions entry in
`~/.pi/agent/settings.json`.

Herdsman agents inherit the lead's model unless a definition pins one. On work
machines (devx detected), setup copies `home/pi-agent/agents/work/` into
`~/.pi/agent/agents/`: `scout` and `reviewer` use Claude Sonnet 5.5 with high
thinking. Sonnet 5.5 is the weakest model allowed for delegated work; do not
pin Claude 4.x or Haiku models. A test enforces this floor. The copies are not
symlinks because Herdsman ignores symlinked definitions. A pinned model keeps the bundled `noExtensions` policy, so each
override loads the Shopify AI proxy extension explicitly. Setup replaces or
removes only files that carry the `# Managed by dotfiles:` marker.

Generated theme files, caches, machine-local configuration, and secret-bearing
environment files are ignored. Never add credentials to the repository; use the
system keychain, 1Password, or untracked local environment files instead.

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
On macOS, missing
Brewfile dependencies are installed with `--no-upgrade`; workstation-wide
upgrades are intentionally left as a separate maintenance action.

### Supported systems

- **macOS:** Homebrew packages, app configuration, launch agents, and shared
  shell/editor configuration.
- **Arch/Omarchy Linux:** `pacman`/`yay` packages, Hyprland, keyd, Omarchy, and
  shared shell/editor configuration.

Linux T2 suspend support requires an explicit privileged run after the normal
user setup:

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
Ruby with `YAML.safe_load_file`, ShellCheck, Bash, and Zsh. Neovim and tmux enable
additional isolated integration tests.

Measure warm startup locally (no cache deletion or dependency installation):

```sh
python3 scripts/benchmark.py --runs 21
```

This measures startup plus immediate exit, without a TTY. It does not measure
first-prompt readiness, deferred plugins, or LSP initialization.

## Maintenance

```sh
# Install anything newly added to the Brewfile without upgrading everything
brew bundle install --no-upgrade --file ./Brewfile

# Deliberately upgrade managed Homebrew dependencies
brew bundle upgrade --file ./Brewfile

# Start heavyweight development services only when needed
brew services start postgresql@14 # or mysql@8.4, redis, ollama

# Update Neovim plugins, then review and commit lazy-lock.json
nvim '+Lazy update'
```

macOS launch-agent setup is separate from package installation and runs after
binaries are linked. Re-running `scripts/services_mac.sh` also repairs unloaded
managed jobs. Clipboard agents remain opt-in. tmux plugin installation uses a
private, sessionless server and checks every declared plugin without touching
your active tmux sessions.

Database servers and Ollama are installed but deliberately not enabled at
login by this setup. Previously enabled services are not stopped automatically. `home/config/nvim/lazy-lock.json` is committed so a fresh machine gets the same
plugin revisions. Generated theme files, caches, machine-local configuration,
and secret-bearing environment files are ignored. Never add credentials to the
repository; use the system keychain, 1Password, or untracked local environment
files instead.

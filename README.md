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
files are preserved unless replacement is confirmed. On macOS, missing
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
Lua compilation checks when available, and the Node test suite. The same check
runs in GitHub Actions.

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

Database servers and Ollama are installed but deliberately not enabled at
login, keeping idle CPU and memory use low. `home/config/nvim/lazy-lock.json` is committed so a fresh machine gets the same
plugin revisions. Generated theme files, caches, machine-local configuration,
and secret-bearing environment files are ignored. Never add credentials to the
repository; use the system keychain, 1Password, or untracked local environment
files instead.

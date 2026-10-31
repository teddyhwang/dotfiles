# Dotfiles

Personal macOS and Arch/Omarchy configuration for Bash, Zsh, Neovim, Herdr,
tmux, terminal emulators, and desktop tools.

## Install

### New Mac: start in the built-in Terminal

No configured Git identity, GitHub login, SSH key, Homebrew, or alternate shell
is required. In Terminal, use your normal macOS administrator account and run:

```sh
bootstrap="$(mktemp)" &&
  curl --disable -fsSL --connect-timeout 10 --max-time 120 \
    https://raw.githubusercontent.com/teddyhwang/dotfiles/main/bootstrap.sh -o "$bootstrap" &&
  /bin/sh "$bootstrap"
```

This downloads the standalone script before executing it; a failed download
never runs a partial script. You are trusting code from this repository—inspect
the downloaded file first if you prefer. Do **not** use `sudo`.

The bootstrap opens Apple's Command Line Tools installer if needed. **Finish the
installation window, then press Return in Terminal.** It verifies Git, clones
this public repository over HTTPS, and runs `setup.sh` with interactive prompts.
Rerunning it reuses a verified existing checkout without pulling or changing local
work. Failed clones are cleaned up; failed setup runs keep the checkout for retry.
If Command Line Tools are not ready yet, finish their installation and rerun the
same command. After success, open a new Terminal window or run `exec /bin/zsh -l`.

#### Manual alternative

If you prefer to run the individual steps, install Apple's Command Line Tools first:

```sh
xcode-select --install
```

**Wait for the installer to finish**, then verify Git actually runs. If macOS
says the tools are already installed, proceed to this check:

```sh
git --version
```

Clone this public repository over **HTTPS**, not SSH. Cloning does not require
`user.name`, `user.email`, a signing key, or GitHub authentication:

```sh
mkdir -p ~/src/github.com/teddyhwang
git clone https://github.com/teddyhwang/dotfiles.git ~/src/github.com/teddyhwang/dotfiles
cd ~/src/github.com/teddyhwang/dotfiles
./setup.sh
```

Run setup normally, **not with `sudo`**. Homebrew will request administrator
authorization when needed. Allow time for downloads, applications and source
builds. If a step fails, fix the reported problem and rerun `./setup.sh` from the
same checkout; do not clone over an existing directory. A failed Brewfile install
stops setup before linking, rather than claiming an incomplete install succeeded.

After success, open a **new Terminal window**, or replace the current shell:

```sh
exec /bin/zsh -l
```

The [new Mac checklist](docs/mac-setup.md) covers preparation, first-run checks,
Git/GitHub access, keys, application permissions, and what setup does not restore.

### Existing checkout / Linux

Run `./setup.sh` from the checkout (or by its absolute path). Linux requires
working Git, curl, readlink, and the Arch/Omarchy package-management prerequisites.

The setup is rerunnable and can be run from any working directory. Existing
configuration files are kept unless replacement is confirmed; declining a prompt
keeps that configuration unmanaged, so review any skipped items. Confirmed replacements are
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

This runs shell syntax checks, ShellCheck, structured-config parsing, Node and
Lua syntax checks when available, and the Node test suite. GitHub Actions
runs the same check on Linux and macOS. Validation needs Node 24+, jq, taplo,
yq (mikefarah's Go version), ShellCheck, Bash, and Zsh. Neovim and tmux enable
additional isolated integration tests.

The repository's own code is shell or Node only; see `AGENTS.md` for the
language rules.

Measure warm startup locally (no cache deletion or dependency installation):

```sh
node scripts/benchmark.mjs --runs 21
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

# Start the local model service only when needed
brew services start ollama

# Optional databases are no longer in the personal Brewfile; install on demand
brew install postgresql@14 # or mysql@8.4, redis, memcached
brew services start postgresql@14

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

### Optional UniFi MCP relay (macOS)

Prefer granting the actual terminal/Pi execution context **Local Network** access
in macOS System Settings → Privacy & Security, verifying direct connectivity
from that context, then setting the MCP endpoint to `192.168.1.1:443` and
reconnecting MCP. Apple `nc` success alone does not prove Node/uv connectivity.

If you explicitly choose a persistent relay instead, run from this checkout:

```sh
./scripts/services_mac.sh --unifi-relay
```

Confirm installation when prompted. Normal setup never installs this relay.
It installs `~/Library/LaunchAgents/unifi-relay.plist` (`localhost.unifi-relay`):
launchd listens only on `127.0.0.1:12443` and starts `/usr/bin/nc -G 5
192.168.1.1 443` per connection. TLS bytes pass through unchanged; this provides
no authentication for other local users/processes and does not change TCC.
The command does not edit MCP settings; the relay endpoint is
`UNIFI_NETWORK_HOST=127.0.0.1`, `UNIFI_NETWORK_PORT=12443`.

Setup requires system `nc`, `launchctl`, and `lsof`. For an unloaded relay it
refuses any listener on TCP 12443, without stopping processes. Inspect with
`lsof -nP -iTCP:12443 -sTCP:LISTEN`; if an old manual relay owns the port, identify
its owner and arrange an explicit manual handoff before retrying. Never stop an
unidentified listener. A matching loaded agent is left alone; differing plist
files require consent and are backed up under `~/.local/state/dotfiles/backups`.

Diagnose with `launchctl print gui/$(id -u)/localhost.unifi-relay` and the `lsof`
command above. A listener is not proof of controller connectivity; reconnect
MCP and try a read-only request. If bootstrap fails (including a port race),
resolve the reported conflict and rerun the opt-in command. To disable manually:
`launchctl bootout gui/$(id -u)/localhost.unifi-relay`, then remove only the
verified managed `~/Library/LaunchAgents/unifi-relay.plist`. No live deployment
or endpoint migration is performed by adding this repository wiring.

Ollama remains in the personal Brewfile but is not enabled at login by this
setup. Optional database servers remain in the work snapshot, not the personal
list. Pruning the personal Brewfile does not uninstall existing packages, delete
application/database data, or stop previously enabled services. Avoid treating
`brew bundle cleanup --force` as part of this pruning: installed packages outside
the curated list can still be in use.
`home/config/nvim/lazy-lock.json` is machine-local and ignored by Git. Herdr setup
uses its `herdr-splits.nvim` revision when present, or a pinned fallback from
`scripts/herdr.sh` before Neovim has installed the plugin. Neovim's Herdr plugin
also synchronizes the Herdr side when it builds or loads inside Herdr.

### Mosh access on macOS

Mosh is included in `Brewfile`. Enable **Remote Login** in System Settings →
General → Sharing for the intended users, then connect from another machine:

```sh
mosh teddyhwang@teddys-mac-mini.local
```

Mosh authenticates through SSH and starts `mosh-server` per session; there is no
persistent service to enable. `home/.zshenv` exposes Homebrew binaries to
noninteractive SSH commands without loading interactive shell configuration.
Existing SSH passwords/authorized keys remain unchanged. The client needs SSH
(TCP 22) and direct access to Mosh's UDP ports (60000–61000); allow `mosh-server`
in the macOS firewall if prompted. No router port forwarding is set up here.

If a Homebrew dependency upgrade leaves Mosh with a missing protobuf library,
run `brew reinstall --yes mosh` to rebuild the existing HEAD installation.

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

### Zed

Zed follows the Neovim config; change Neovim first, then mirror the change in
`home/config/zed`. Setup links `settings.json`, `keymap.json` and `tasks.json`
into `~/.config/zed` one file at a time, because Zed writes other state there.

- `settings.json` turns on vim mode and copies Neovim's options. Comments name
  the Neovim option or plugin behind each setting.
- `keymap.json` uses `\` as the leader, as Neovim does. It has the custom
  mappings from `lua/config/keymaps.lua`, the plugin mappings, and the LazyVim
  defaults that have a Zed action.
- `tasks.json` runs the terminal programs: lazygit, yazi (the chosen file
  opens in Zed), the AI CLIs, `zed-test-file` for `\T`, and `zed-other-file`
  for the other.nvim alternate file (`\oo`).

The tinty hook `tinty-zed-hook` installs each scheme as the theme "Tinted
Theming", with the highlight overrides from Neovim's `config/colorscheme.lua`.
`tinty apply` therefore switches Zed and Neovim together.

### Rex

`home/config/rex/init.lua` gives Rex the tmux and Herdr key bindings, with
`ctrl+a` as the prefix: `-` and `|` split, `h/j/k/l` focus, `H/J/K/L` move,
`e` enters resize mode, `c` opens a tab, `0`-`9` pick a tab (zero-based, like
Herdr), `N` opens a session, and `s` switches session. Press `ctrl+a` twice to send a literal `ctrl+a`. Without the prefix,
`ctrl+h/j/k/l` move between panes, as in tmux. Rex passes the keys to Vim, and
Neovim's `config/keymaps.lua` runs `rex focus` at Vim's edge. Setup links only
`init.lua` into `~/.config/rex`. Check it with `rex config check` and apply it
with `ctrl+a r` or `rex config reload`. Rex's session switcher and palette are
native popups that never see `init.lua`, so Hammerspoon's `rex_pickers.lua`
turns `ctrl+j/k` into down and up there, and only when a text field other than
a terminal has focus.

Rex keeps its font and theme in macOS defaults (`com.superlogical.rex`), not
in `init.lua`. `scripts/rex.sh`, run by setup, writes only those keys
(JetBrainsMono Nerd Font 12, Merino dark and light themes, and the standard
inactive-window style turned off so a backgrounded window keeps full-strength
colors) and leaves window and server preferences alone. Change the values in that script, then run
`sh scripts/rex.sh` and restart Rex.

### Pi extensions

Personal Pi extension code and tests live in
[`teddyhwang/pi-extensions`](https://github.com/teddyhwang/pi-extensions).
`setup.sh` installs the Pi and QMD CLIs when missing, then provisions the shared package baseline
in [`apps/pi/packages.json`](apps/pi/packages.json): personal extensions, Vim
mode, web search and fetch (`pi-web-access`), Herdsman, Autoresearch and
Anthropic authentication support. Git sources
use HTTPS rather than requiring SSH keys. The personal `pi-extensions` repository
is private: setup checks GitHub authentication, launches browser login when
needed in a terminal, and runs `gh auth setup-git` before provisioning Pi.
Unattended setup requires an existing GitHub login; otherwise it stops with
instructions rather than skipping private extensions. Public packages need no GitHub login;
setup never copies credentials from another computer.

To install or repair Pi and its packages without rerunning workstation setup:

```sh
cd ~/src/github.com/teddyhwang/dotfiles
sh scripts/pi.sh
```

The helper also finds Pi in `~/.local/bin` or `~/.pi/agent/bin` before those
locations reach a new shell's PATH. If missing, it installs the official
`@earendil-works/pi-coding-agent` npm package with `--ignore-scripts` into
`~/.local` (no sudo). The helper also installs `@tobilu/qmd` into `~/.local`
when `qmd` is absent from both PATH and `~/.local/bin`. QMD uses normal npm
lifecycle scripts for its native dependencies. Existing Pi and QMD installations
are not upgraded or replaced. QMD collections, indexing and model downloads
remain explicit steps; setup only installs the CLI.
It installs missing packages and repairs
missing package/build artifacts, not routine upgrades. Existing package sources,
pins, resource filters and unrelated settings are preserved. New entries get the
baseline resource filters; top-level resource/tool defaults are filled only when
absent. Settings changes preserve a private backup under
`~/.local/state/dotfiles/backups/`.

Authentication, MCP connections, model choices and other machine-local settings
are not copied from another machine. See the [new Mac checklist](docs/mac-setup.md).
This repository manages Pi configuration and integration wiring only; do not
add extension implementations here or maintain separate personal copies in
`~/.pi/agent/extensions`. After package changes, use `/reload` in active sessions.

`home/pi-agent/AGENTS.md` holds the global Pi rules: use `edit` for file
changes, do not poll with `sleep`, batch independent calls, and how to read
links. Setup links it to `~/.pi/agent/AGENTS.md`, and Pi loads it in every
working directory when a session starts. These portable rules assume only
pi-extensions: other tools, agents or CLIs may still be absent or deliberately
filtered on an existing machine, so references to them stay conditional
("if `bg_wait` is available"). `tests/pi-agents-md.test.mjs` enforces this.

The same file carries the always-on Toil Tracker trigger line, so every Pi
session (including Herdsman agents) journals avoidable friction. Setup links the
skill from `.agents/skills/toil-tracker` to `~/.agents/skills/toil-tracker`
(keeping an existing install) and seeds an empty machine-local journal at
`~/toil/index.md` from the skill's template, never overwriting one. Change the
journal's action map in that index header to grant direct fixes or filing.

The package's `/skill:home-assistant` is the maintained Home Assistant workflow:
access, safe updates, dashboards, HomeKit, backups and verification. This repo
owns only the nonsecret site configuration and runbook at
`home/config/home-assistant/{agent.json,site.md}`, linked to
`~/.config/home-assistant/`. The generic skill/API helper and its behavioral
tests live in the canonical Pi package. Read and update the site runbook during
HA work instead of rediscovering connection details and decisions from memory.
Never store tokens, PINs, passwords or full auth/integration-storage dumps in
these files. `/reload` makes a newly installed or updated skill available.

Inside Herdr, the `pi` shell function in `home/shared/functions` handles
`pi --worktree [name]` before pi starts. Herdr creates the checkout on branch
`pi-worktree/<name>` from the current `HEAD` and focuses its new workspace.
The function then types `pi` and the remaining arguments into that
workspace's pane, in the same subdirectory, so no pi starts in the launching
pane. When that pi exits, the pane asks whether to remove the worktree and
close its workspace. Enter confirms only when nothing would be lost. Commits
always survive: the branch is kept unless it has no new commits, and a
detached `HEAD` gets a safety branch. Resumed sessions (`-c`, `-r`,
`--session`, `--fork`) and print/JSON/RPC runs fall through to the package's
in-session worktree.

The former dotfiles `session-tab-name` extension now belongs to that package.
Setup removes only its exact old dotfiles symlink, preserving third-party
extensions and user-maintained files. See `AGENTS.md` for the ownership guardrail.

[Pi Herdsman](https://github.com/boadij/pi-herdsman) uses the tested Git revision
in the package baseline, rather than the older npm runtime. Its Git checkout
needs an explicit build: Pi's production-only dependency install does not run
Herdsman's `prepack` hook or install esbuild. The setup helper installs only
`esbuild@0.28.2` in `~/.cache/pi-herdsman-build`, links a missing build dependency,
and runs Herdsman's own build script when its bundled outputs are missing. It
does not patch third-party source or install another copy of Pi's host packages.
Existing local Herdsman clones and their package declarations remain supported.

When herdr is available, the helper also runs `herdr integration install pi`;
Herdr continues to own that generated integration. No sessions are started or
restarted. Do not use the upstream Herdsman `install.sh`: it installs a different
Pi/herdr runtime.

Updates remain explicit. After changing/updating a Git package's ref, rerun
`sh scripts/pi.sh` to rebuild any removed Herdsman outputs, then `/reload`.
`pi update --extensions` updates managed packages, not local clones; a configured
Git commit stays pinned. Local clones still need their own deliberate Git update.

Keep Pi's default strict tool calling for Anthropic models; a test enforces
this. Strict calling stops agents from calling tools they do not have. Before
Herdsman v0.20.0, its tools exceeded Anthropic's grammar limit and every request
failed with HTTP 400. If that error comes back, update Herdsman and restart old
sessions. Do not turn strict tools off.

Herdsman is the default bounded-delegation executor; do not expose both it and
legacy agent-teams for routine delegation. Camofox is removed from the personal
package and excluded by the baseline for older checkouts. In
`~/.pi/agent/settings.json`, use
Pi's package resource filters (merge into existing entries, preserving their
sources and other filters):

```json
{
  "packages": [
    {
      "source": "git:git@github.com:teddyhwang/pi-extensions",
      "extensions": ["-extensions/agent-teams/index.ts", "-extensions/camofox-browser/index.ts"]
    },
    {
      "source": "https://github.com/davebcn87/pi-autoresearch",
      "skills": []
    }
  ],
  "skills": [
    "-skills/find-skills/SKILL.md",
    "-../../.agents/skills/find-skills/SKILL.md"
  ]
}
```

This is a selection fragment, **not a replacement settings file**. Keep the
Herdsman, Vim, search, authentication and other package entries. Remove an old
explicit `+…find-skills/SKILL.md` inclusion before adding its exclusions; both
skill roots are excluded because personal Pi skills may symlink to `.agents`.
Fresh installs receive these selections automatically. Existing package filters
and top-level resource selections remain machine-local and are not overwritten;
merge this fragment when deliberately changing an existing installation.

The generic finder routes ordinary how-to questions through skill discovery;
keep it opt-in. Autoresearch's recipes are also opt-in until their correctness
checks and finalization safeguards are reviewed: the inspected create recipe
masks typecheck failures with `| grep -i error || true`, and finalization can
fail on deleted paths. This filters the **skills only**, preserving the gated
`/autoresearch` runtime and experiment data; it does not patch third-party
installer-managed files. Deliberately load a reviewed recipe for one session:

```sh
pi --skill ~/.pi/agent/git/github.com/davebcn87/pi-autoresearch/skills/autoresearch-create/SKILL.md
pi --skill ~/.pi/agent/skills/find-skills/SKILL.md
```

An excluded skill is not advertised or available through its normal `/skill:`
command unless loaded explicitly. After changing selections, use `/reload`;
start a fresh session if previously activated tools remain declared. Legacy
agent-teams code remains installed for workflows explicitly needing its task
board/budget controls; select a single delegation owner rather than silently
substituting APIs.

Herdsman agents inherit the lead's model unless a definition pins one. Setup
copies the matching profile into `~/.pi/agent/agents/`. Personal machines use
`home/pi-agent/agents/personal/`: `scout` and `implementer` run Anthropic
Claude Sonnet 5.5 (high and medium thinking respectively); `researcher` and
`reviewer` run Claude Opus 5.5 with high thinking. All keep the bundled
prompts and tools. Each role definition includes explicit authority boundaries,
coordination rules, and deliverable requirements. The bundled
`researcher` tools (`web_search`, `fetch_content`, `get_search_content`,
`source_check`) come from `pi-web-access`, which needs no API key: it searches
through Exa's keyless endpoint or the Codex login and fetches pages over plain
HTTP. Its curator window and browser-cookie access stay off. `generalist` still
inherits the lead's model. These providers need their normal Pi authentication.

On work machines (devx detected), setup uses `home/pi-agent/agents/work/`
instead:

- `researcher` uses Claude Fable 5.1, the strongest model, with xhigh thinking.
  Its tool list uses the installed shop-pi-fy search and fetch tools, so it can
  read primary sources instead of only search snippets.
- `scout` uses Claude Sonnet 5.5 and `reviewer` uses Claude Opus 5.5, both
  with high thinking. Their appended bodies say they have no shell, because
  project instructions full of shell commands led them to call `bash`, which
  they do not have. Herdsman v0.27.0 removed its own shell text, but scouts
  still called `bash` without these bodies.
- `implementer` uses Claude Sonnet 5.5 with medium thinking. It also loads the
  shop-pi-fy `background-jobs` extension and allows `bg_*` tools, so it waits
  on long jobs with `bg_wait` instead of polling with `sleep`. If you remove
  `background-jobs` with `/pkg rm`, remove it from this definition too. It
  also loads `shell-guard` from pi-extensions, which blocks sleep polling,
  bash edits of tracked files, and destructive git and `pkill -f` commands.
- `data-auditor` is a new read-only role for checking claims against local
  data, such as memory-sync audits. It uses Claude Sonnet 5.5. Its only shell
  is `readonly_bash` from pi-extensions' `readonly-shell`, which runs `rg`,
  `jq` and `python3` in a macOS sandbox without network or filesystem writes
  outside a per-call temp directory. It requires installed Bash 4+; Linux
  execution fails closed until host control sockets can be isolated. This is
  not a confidentiality or complete process-isolation boundary. A new role
  has its own prompt and must not set `bodyMode`.

`home/pi-agent/agents/generalist.md` installs on every machine. It keeps the
lead's model and appends edit-tool and no-polling rules. The bundled
implementer and generalist bodies replace Pi's system prompt, which drops its
rule to change files with `edit`.

Sonnet 5.5 is the weakest Claude model allowed for delegated work; do not pin
Claude 4.x or Haiku models. Tests enforce this floor and both profiles' explicit
implementer/reviewer model and thinking levels. The copies are not symlinks
because Herdsman ignores symlinked definitions. A pinned model keeps the
bundled `noExtensions` policy, so the `scout` and `reviewer` overrides load
the Shopify AI proxy extension explicitly. The bundled `researcher` keeps
extension discovery and needs no extension entry. An override with a body
must set `bodyMode: append`, or its body replaces the bundled prompt; a test
enforces this. Setup replaces or removes only files that carry the
`# Managed by dotfiles:` marker; unmarked interactive overrides are preserved.
Changes affect new agent assignments, not agents already running. Use
`/agents definitions` to customize models locally.

Generated theme files, caches, machine-local configuration, and secret-bearing
environment files are ignored. Never add credentials to the repository; use the
system keychain, 1Password, or untracked local environment files instead.

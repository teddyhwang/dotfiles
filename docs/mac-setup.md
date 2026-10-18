# New Mac setup checklist

This is a fresh-install path, not a full-machine backup restore. Start with the
built-in Terminal and an administrator account. No Git identity, SSH keys,
GitHub login, Homebrew, or third-party terminal is needed to fetch the dotfiles.
The repository is public; HTTPS cloning is anonymous.

## Before the new Mac arrives

- Have your Apple ID, password manager, recovery methods, and service logins
  available independently of the old computer.
- Make a current encrypted backup. Identify machine-local files you actually
  need: SSH/GPG keys, Git identity and signing settings, authorized keys, shell
  secrets, Pi settings/authentication, project `.env` files, app data, and
  databases. These are deliberately **not** stored in this repository.
- Decide whether to provision new SSH/signing keys or securely migrate existing
  ones. Do not put private keys, tokens, recovery codes, or auth files in Git.
- Review the personal `Brewfile`. A Mac without `devx` uses this list, not the
  much larger work snapshot. It includes applications and a few source/HEAD
  builds, so allow substantial download/build time and free disk space.
- If migrating services such as Plex, plan their data/configuration migration
  separately; installing an application does not restore its library.

## First Terminal session

1. Complete macOS onboarding and connect to the internet. Use your normal
   administrator account; do not start a root shell or run setup with `sudo`.
2. Download and execute the standalone bootstrap script:

   ```sh
   bootstrap="$(mktemp)" &&
     curl --disable -fsSL --connect-timeout 10 --max-time 120 \
       https://raw.githubusercontent.com/teddyhwang/dotfiles/main/bootstrap.sh -o "$bootstrap" &&
     /bin/sh "$bootstrap"
   ```

   This runs code from this repository; you can inspect the downloaded file
   before executing it. A failed download never executes a partial file.
   No Git or Homebrew is needed to download it. The manual alternative remains
   in the README.

3. If prompted, finish Apple's Command Line Tools installation window, then
   press Return in Terminal. The script verifies working Git, clones the public
   HTTPS repository into `~/src/github.com/teddyhwang/dotfiles`, and runs setup.
   If the tools are not ready, finish installing them (or resolve Software
   Update errors) and rerun the same command. A failed clone is cleaned up.

   Git does not need your name/email, signing key, or GitHub authentication to
   clone. An existing matching checkout is reused **without a pull** or changes
   to local work; unrelated directories/repositories and escaping symlinks are
   refused rather than replaced.

4. Stay at the terminal for Homebrew's installer/password prompts and optional
   configuration/clipboard-agent confirmations. A fresh home should not need
   replacement confirmations for Ghostty or btop. If you decline replacing an
   existing configuration, it is preserved rather than installed: review those
   skipped items instead of assuming every configuration is managed.
5. If setup exits with an error, address the named failure and rerun the
   bootstrap command, or run the existing checkout directly:
   `/bin/sh ~/src/github.com/teddyhwang/dotfiles/setup.sh`.
   A package failure stops subsequent configuration. Do not use
   `brew bundle cleanup --force`, remove an existing checkout, or delete your
   home configuration to make a rerun work. Incomplete shell-plugin installs
   are staged/repaired and existing incomplete directories are backed up.
6. Open a new Terminal window, or run:

   ```sh
   exec /bin/zsh -l
   ```

   Setup is a child process; it cannot change the environment of the original
   Terminal shell. First Zsh launch also downloads its configured plugins and
   may take longer than subsequent launches.

## First-run verification

In the new shell:

```sh
command -v brew git zsh nvim tmux herdr bat fzf
brew --prefix
brew bundle check --no-upgrade --file ~/src/github.com/teddyhwang/dotfiles/Brewfile
ls -ld ~/.shared ~/.config/ghostty ~/.config/btop
bat --list-themes | grep base16-256
```

Native Homebrew on an Apple Silicon Mac mini should report `/opt/homebrew`.
Open Ghostty and Neovim once; Neovim downloads its own plugins/tools. Theme
initialization also downloads tinty theme repositories. If the terminal theme
is missing, check network access and run `tinty apply base16-seti` in the new
shell to see errors rather than relying on quiet shell startup.

Run repository validation after the packages are installed:

```sh
cd ~/src/github.com/teddyhwang/dotfiles
PATH="$(brew --prefix ruby)/bin:$PATH" ./scripts/check.sh
```

Apple's system Ruby is not sufficient for this check. Tests isolate HOME and
mock installation/service operations; they do **not** prove Apple's installer,
all current upstream downloads, or application permissions work on a wiped Mac.
A disposable native macOS installation remains the final end-to-end test.

## Git identity, authentication, and signing

Setup adds the shared Git config without inventing an identity or copying keys.
Set your real name and a GitHub-verified email before making commits:

```sh
git config --global user.name "Your Name"
git config --global user.email "your-verified-email@example.com"
```

Signing is now **opt-in per machine**, not an unconditional shared requirement.
An existing explicit `commit.gpgsign` setting is preserved. If you migrate a
configuration with signing enabled, provision its key before committing.
For GPG signing, after securely importing/provisioning and verifying your key:

```sh
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true
```

Users who previously relied solely on the shared signing default should also
set this explicit local preference on existing machines if they want to keep
signing. This change avoids requiring a nonexistent private key on a fresh Mac.

Cloning and local commits do not require GitHub authentication; pushing does.
For HTTPS, `gh auth login` followed by `gh auth setup-git` can configure access.
Alternatively, provision an SSH key and authorize it on GitHub before switching
this checkout's remote to SSH. Do not copy an old Git config blindly: it may
contain stale key paths, credential helpers, or work-only includes.

## Manual steps setup does not perform

- **Accounts and data:** password manager, Apple/iCloud, browser profiles,
  application sign-ins, licences, SSH/GPG keys, cloud/API credentials, private
  project access, and data restores.
- **macOS permissions:** grant Accessibility/Input Monitoring to the window and
  input tools you actually use (Amethyst, Hammerspoon, Karabiner, Raycast, etc.),
  plus other permissions when macOS asks. Review Login Items in System Settings.
- **Displays:** arrange the monitors in System Settings. Hammerspoon uses display
  ordering; verify its application placement on the new monitor arrangement.
- **Remote access:** Remote Login is opt-in in System Settings. Check hostname,
  authorized users/keys, firewall, and Mosh connectivity before relying on it.
  No router ports are opened. Existing aliases still name the existing hosts.
- **Servers:** Ollama is installed but not enabled at login. Optional databases
  are not in the personal Brewfile. Install/start them deliberately if needed.
- **Pi:** the CLI, packages, logins, and machine-local `settings.json` are not
  installed/restored by setup. The linked model/rule/agent files are only
  configuration. Install the CLI and canonical `pi-extensions` package, then
  restore/review package selections and authenticate. See the README's Pi
  section for package/Herdsman instructions; HTTPS avoids an SSH prerequisite.
- **Other apps/toolchains:** only Brewfile entries are installed; other linked
  app configurations do not imply the app is installed. Project runtimes,
  language dependencies, Neovim's tools, and optional integrations may require
  their own first-run downloads.
- **Home Assistant access:** the nonsecret site runbook is linked, not its
  token or SSH authorization. Follow it when provisioning access.

Clipboard agents remain optional and loopback-only. Rerunning service setup
repairs managed unloaded jobs; differing/foreign files are not permission to
silently overwrite them. Original replaced files and incomplete plugin
installations are preserved under `~/.local/state/dotfiles/backups/`.

# SSH remote commands (including Mosh startup) read .zshenv, not .zshrc.
# Only append missing Homebrew paths: stay silent, avoid subprocesses, and
# preserve inherited PATH precedence (for example, an active virtualenv).
if [[ -x /opt/homebrew/bin/brew ]]; then
  [[ ":$PATH:" == *:/opt/homebrew/bin:* ]] || path+=(/opt/homebrew/bin)
  [[ ":$PATH:" == *:/opt/homebrew/sbin:* ]] || path+=(/opt/homebrew/sbin)
elif [[ -x /usr/local/bin/brew ]]; then
  [[ ":$PATH:" == *:/usr/local/bin:* ]] || path+=(/usr/local/bin)
  [[ ":$PATH:" == *:/usr/local/sbin:* ]] || path+=(/usr/local/sbin)
fi

# Rex, SSH and other non-desktop logins on Linux start without SSH_AUTH_SOCK,
# so git and ssh read the key file and ask for its passphrase (Pi's package
# update hangs on it). Use the desktop's GCR agent, which unlocks the key from
# the keyring. Keep an inherited agent, such as a forwarded one.
if [[ -z $SSH_AUTH_SOCK && -S ${XDG_RUNTIME_DIR:-/nonexistent}/gcr/ssh ]]; then
  export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh
fi

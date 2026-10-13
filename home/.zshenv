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

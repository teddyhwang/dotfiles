if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
export BASE16_THEME_DEFAULT="seti"
export EDITOR='nvim'
export FZF_ALT_C_OPTS="--preview='tree -L 1 {}'"
export FZF_CTRL_T_COMMAND="fd --type file --follow --hidden --exclude .git"
export FZF_CTRL_T_OPTS="--preview 'bat --theme=base16-256 --style=numbers --color=always --line-range :500 {}'"
export FZF_DEFAULT_COMMAND="rg --files --hidden"
export FZF_DEFAULT_OPTS='--height 30% --border'
export FZF_TMUX_OPTS='-d 40%'
export HIGHLIGHT_STYLE=base16/seti
# vivid generate molokai
export LS_COLORS="pi=0;38;2;0;0;0;48;2;102;217;239:mi=0;38;2;0;0;0;48;2;255;74;68:di=0;38;2;102;217;239:ln=0;38;2;249;38;114:no=0:so=0;38;2;0;0;0;48;2;249;38;114:*~=0;38;2;122;112;112:tw=0:bd=0;38;2;102;217;239;48;2;51;51;51:cd=0;38;2;249;38;114;48;2;51;51;51:ex=1;38;2;249;38;114:or=0;38;2;0;0;0;48;2;255;74;68:fi=0:st=0:ow=0:*.r=0;38;2;0;255;135:*.o=0;38;2;122;112;112:*.p=0;38;2;0;255;135:*.t=0;38;2;0;255;135:*.m=0;38;2;0;255;135:*.c=0;38;2;0;255;135:*.z=4;38;2;249;38;114:*.h=0;38;2;0;255;135:*.d=0;38;2;0;255;135:*.a=1;38;2;249;38;114:*.gz=4;38;2;249;38;114:*.ml=0;38;2;0;255;135:*.nb=0;38;2;0;255;135:*.fs=0;38;2;0;255;135:*.cs=0;38;2;0;255;135:*.xz=4;38;2;249;38;114:*.jl=0;38;2;0;255;135:*.vb=0;38;2;0;255;135:*.la=0;38;2;122;112;112:*.lo=0;38;2;122;112;112:*css=0;38;2;0;255;135:*.7z=4;38;2;249;38;114:*.ex=0;38;2;0;255;135:*.kt=0;38;2;0;255;135:*.cc=0;38;2;0;255;135:*.pl=0;38;2;0;255;135:*.hh=0;38;2;0;255;135:*.rs=0;38;2;0;255;135:*.bz=4;38;2;249;38;114:*.cr=0;38;2;0;255;135:*.md=0;38;2;226;209;57:*.bc=0;38;2;122;112;112:*.pm=0;38;2;0;255;135:*.sh=0;38;2;0;255;135:*.py=0;38;2;0;255;135:*.di=0;38;2;0;255;135:*.ll=0;38;2;0;255;135:*.rm=0;38;2;253;151;31:*.go=0;38;2;0;255;135:*.pp=0;38;2;0;255;135:*.js=0;38;2;0;255;135:*.ts=0;38;2;0;255;135:*.as=0;38;2;0;255;135:*.hs=0;38;2;0;255;135:*.ps=0;38;2;230;219;116:*.gv=0;38;2;0;255;135:*.el=0;38;2;0;255;135:*.so=1;38;2;249;38;114:*.rb=0;38;2;0;255;135:*.hi=0;38;2;122;112;112:*.ko=1;38;2;249;38;114:*.cp=0;38;2;0;255;135:*.td=0;38;2;0;255;135:*.mn=0;38;2;0;255;135:*.ui=0;38;2;166;226;46:*.sql=0;38;2;0;255;135:*.bat=1;38;2;249;38;114:*.bcf=0;38;2;122;112;112:*.xml=0;38;2;226;209;57:*.cpp=0;38;2;0;255;135:*.blg=0;38;2;122;112;112:*.dmg=4;38;2;249;38;114:*.img=4;38;2;249;38;114:*.txt=0;38;2;226;209;57:*.arj=4;38;2;249;38;114:*TODO=1:*.gif=0;38;2;253;151;31:*.tif=0;38;2;253;151;31:*.pyc=0;38;2;122;112;112:*.zst=4;38;2;249;38;114:*.bag=4;38;2;249;38;114:*.eps=0;38;2;253;151;31:*.xmp=0;38;2;166;226;46:*.exe=1;38;2;249;38;114:*.swf=0;38;2;253;151;31:*.out=0;38;2;122;112;112:*.jpg=0;38;2;253;151;31:*.csv=0;38;2;226;209;57:*.mli=0;38;2;0;255;135:*.flv=0;38;2;253;151;31:*.csx=0;38;2;0;255;135:*.m4v=0;38;2;253;151;31:*.otf=0;38;2;253;151;31:*.hxx=0;38;2;0;255;135:*.mid=0;38;2;253;151;31:*.clj=0;38;2;0;255;135:*.yml=0;38;2;166;226;46:*.aux=0;38;2;122;112;112:*.tcl=0;38;2;0;255;135:*.psd=0;38;2;253;151;31:*.pkg=4;38;2;249;38;114:*.dll=1;38;2;249;38;114:*.fsi=0;38;2;0;255;135:*.fnt=0;38;2;253;151;31:*.sty=0;38;2;122;112;112:*.sxi=0;38;2;230;219;116:*.aif=0;38;2;253;151;31:*.zsh=0;38;2;0;255;135:*.bst=0;38;2;166;226;46:*.erl=0;38;2;0;255;135:*.rar=4;38;2;249;38;114:*.xcf=0;38;2;253;151;31:*.pps=0;38;2;230;219;116:*.dox=0;38;2;166;226;46:*.ppt=0;38;2;230;219;116:*.bmp=0;38;2;253;151;31:*.pas=0;38;2;0;255;135:*.svg=0;38;2;253;151;31:*.mkv=0;38;2;253;151;31:*.ttf=0;38;2;253;151;31:*.bin=4;38;2;249;38;114:*.rpm=4;38;2;249;38;114:*.tex=0;38;2;0;255;135:*.apk=4;38;2;249;38;114:*.htm=0;38;2;226;209;57:*.mp4=0;38;2;253;151;31:*.mir=0;38;2;0;255;135:*.wmv=0;38;2;253;151;31:*.odp=0;38;2;230;219;116:*.ppm=0;38;2;253;151;31:*.tar=4;38;2;249;38;114:*.vob=0;38;2;253;151;31:*.bak=0;38;2;122;112;112:*.deb=4;38;2;249;38;114:*.awk=0;38;2;0;255;135:*.com=1;38;2;249;38;114:*.pro=0;38;2;166;226;46:*.mp3=0;38;2;253;151;31:*.ipp=0;38;2;0;255;135:*.elm=0;38;2;0;255;135:*.bbl=0;38;2;122;112;112:*.asa=0;38;2;0;255;135:*.git=0;38;2;122;112;112:*.xlr=0;38;2;230;219;116:*.ogg=0;38;2;253;151;31:*.hpp=0;38;2;0;255;135:*.exs=0;38;2;0;255;135:*.cxx=0;38;2;0;255;135:*.avi=0;38;2;253;151;31:*.ltx=0;38;2;0;255;135:*.tmp=0;38;2;122;112;112:*.vim=0;38;2;0;255;135:*.bz2=4;38;2;249;38;114:*.pod=0;38;2;0;255;135:*.rst=0;38;2;226;209;57:*.ods=0;38;2;230;219;116:*.vcd=4;38;2;249;38;114:*.m4a=0;38;2;253;151;31:*.sxw=0;38;2;230;219;116:*.cfg=0;38;2;166;226;46:*.cgi=0;38;2;0;255;135:*.fls=0;38;2;122;112;112:*.iso=4;38;2;249;38;114:*.kex=0;38;2;230;219;116:*hgrc=0;38;2;166;226;46:*.htc=0;38;2;0;255;135:*.pgm=0;38;2;253;151;31:*.xls=0;38;2;230;219;116:*.gvy=0;38;2;0;255;135:*.mov=0;38;2;253;151;31:*.ics=0;38;2;230;219;116:*.def=0;38;2;0;255;135:*.bib=0;38;2;166;226;46:*.fon=0;38;2;253;151;31:*.php=0;38;2;0;255;135:*.rtf=0;38;2;230;219;116:*.idx=0;38;2;122;112;112:*.ini=0;38;2;166;226;46:*.epp=0;38;2;0;255;135:*.pdf=0;38;2;230;219;116:*.log=0;38;2;122;112;112:*.tml=0;38;2;166;226;46:*.ps1=0;38;2;0;255;135:*.doc=0;38;2;230;219;116:*.tsx=0;38;2;0;255;135:*.lua=0;38;2;0;255;135:*.odt=0;38;2;230;219;116:*.dot=0;38;2;0;255;135:*.mpg=0;38;2;253;151;31:*.pid=0;38;2;122;112;112:*.c++=0;38;2;0;255;135:*.ico=0;38;2;253;151;31:*.jar=4;38;2;249;38;114:*.tbz=4;38;2;249;38;114:*.zip=4;38;2;249;38;114:*.ilg=0;38;2;122;112;112:*.kts=0;38;2;0;255;135:*.h++=0;38;2;0;255;135:*.wma=0;38;2;253;151;31:*.nix=0;38;2;166;226;46:*.inl=0;38;2;0;255;135:*.toc=0;38;2;122;112;112:*.inc=0;38;2;0;255;135:*.ind=0;38;2;122;112;112:*.dpr=0;38;2;0;255;135:*.png=0;38;2;253;151;31:*.fsx=0;38;2;0;255;135:*.sbt=0;38;2;0;255;135:*.pbm=0;38;2;253;151;31:*.tgz=4;38;2;249;38;114:*.bsh=0;38;2;0;255;135:*.wav=0;38;2;253;151;31:*.swp=0;38;2;122;112;112:*.rlib=0;38;2;122;112;112:*.dart=0;38;2;0;255;135:*.h264=0;38;2;253;151;31:*.lock=0;38;2;122;112;112:*.psd1=0;38;2;0;255;135:*.less=0;38;2;0;255;135:*.pptx=0;38;2;230;219;116:*.java=0;38;2;0;255;135:*.flac=0;38;2;253;151;31:*.diff=0;38;2;0;255;135:*.epub=0;38;2;230;219;116:*.orig=0;38;2;122;112;112:*.tiff=0;38;2;253;151;31:*.toml=0;38;2;166;226;46:*.mpeg=0;38;2;253;151;31:*.tbz2=4;38;2;249;38;114:*.docx=0;38;2;230;219;116:*.make=0;38;2;166;226;46:*.fish=0;38;2;0;255;135:*.xlsx=0;38;2;230;219;116:*.bash=0;38;2;0;255;135:*.hgrc=0;38;2;166;226;46:*.purs=0;38;2;0;255;135:*.jpeg=0;38;2;253;151;31:*.html=0;38;2;226;209;57:*.lisp=0;38;2;0;255;135:*.yaml=0;38;2;166;226;46:*.psm1=0;38;2;0;255;135:*.json=0;38;2;166;226;46:*.conf=0;38;2;166;226;46:*.shtml=0;38;2;226;209;57:*.cmake=0;38;2;166;226;46:*passwd=0;38;2;166;226;46:*.xhtml=0;38;2;226;209;57:*shadow=0;38;2;166;226;46:*.scala=0;38;2;0;255;135:*.cache=0;38;2;122;112;112:*.toast=4;38;2;249;38;114:*.patch=0;38;2;0;255;135:*.ipynb=0;38;2;0;255;135:*README=0;38;2;0;0;0;48;2;230;219;116:*.dyn_o=0;38;2;122;112;112:*.cabal=0;38;2;0;255;135:*.mdown=0;38;2;226;209;57:*.swift=0;38;2;0;255;135:*.class=0;38;2;122;112;112:*.matlab=0;38;2;0;255;135:*.dyn_hi=0;38;2;122;112;112:*.gradle=0;38;2;0;255;135:*.flake8=0;38;2;166;226;46:*LICENSE=0;38;2;182;182;182:*.ignore=0;38;2;166;226;46:*.groovy=0;38;2;0;255;135:*INSTALL=0;38;2;0;0;0;48;2;230;219;116:*TODO.md=1:*.config=0;38;2;166;226;46:*COPYING=0;38;2;182;182;182:*.gemspec=0;38;2;166;226;46:*Makefile=0;38;2;166;226;46:*.desktop=0;38;2;166;226;46:*Doxyfile=0;38;2;166;226;46:*TODO.txt=1:*setup.py=0;38;2;166;226;46:*.kdevelop=0;38;2;166;226;46:*.fdignore=0;38;2;166;226;46:*.cmake.in=0;38;2;166;226;46:*.rgignore=0;38;2;166;226;46:*.markdown=0;38;2;226;209;57:*.DS_Store=0;38;2;122;112;112:*configure=0;38;2;166;226;46:*README.md=0;38;2;0;0;0;48;2;230;219;116:*COPYRIGHT=0;38;2;182;182;182:*.scons_opt=0;38;2;122;112;112:*SConscript=0;38;2;166;226;46:*INSTALL.md=0;38;2;0;0;0;48;2;230;219;116:*.gitconfig=0;38;2;166;226;46:*README.txt=0;38;2;0;0;0;48;2;230;219;116:*.localized=0;38;2;122;112;112:*Dockerfile=0;38;2;166;226;46:*.gitignore=0;38;2;166;226;46:*SConstruct=0;38;2;166;226;46:*CODEOWNERS=0;38;2;166;226;46:*MANIFEST.in=0;38;2;166;226;46:*INSTALL.txt=0;38;2;0;0;0;48;2;230;219;116:*Makefile.in=0;38;2;122;112;112:*.travis.yml=0;38;2;230;219;116:*.synctex.gz=0;38;2;122;112;112:*LICENSE-MIT=0;38;2;182;182;182:*Makefile.am=0;38;2;166;226;46:*.gitmodules=0;38;2;166;226;46:*.applescript=0;38;2;0;255;135:*CONTRIBUTORS=0;38;2;0;0;0;48;2;230;219;116:*appveyor.yml=0;38;2;230;219;116:*.fdb_latexmk=0;38;2;122;112;112:*configure.ac=0;38;2;166;226;46:*.clang-format=0;38;2;166;226;46:*CMakeLists.txt=0;38;2;166;226;46:*LICENSE-APACHE=0;38;2;182;182;182:*.gitattributes=0;38;2;166;226;46:*CMakeCache.txt=0;38;2;122;112;112:*CONTRIBUTORS.md=0;38;2;0;0;0;48;2;230;219;116:*.sconsign.dblite=0;38;2;122;112;112:*requirements.txt=0;38;2;166;226;46:*CONTRIBUTORS.txt=0;38;2;0;0;0;48;2;230;219;116:*package-lock.json=0;38;2;122;112;112:*.CFUserTextEncoding=0;38;2;122;112;112"
export NVM_DIR="$HOME/.nvm"
if [ $SPIN ]; then
  export PATH="/opt/rubies/*/lib/ruby/gems/*/gems/*/bin:$PATH"
  export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
  alias token='bundle config --global PKGS__SHOPIFY__IO "token:$(gsutil cat gs://dev-tokens/cloudsmith/shopify/gems/latest)"'
  alias mycli='mycli -u root -P $MYSQL_PORT'
fi

alias brighter='tinty apply base16-synth-midnight-dark'
alias dark='tinty apply base16-seti'
alias darker='tinty apply base16-3024'
alias light='tinty apply base16-solarized-light'
alias lighter='tinty apply base16-one-light'

alias gpgstart='gpgconf --launch gpg-agent'
alias main='git checkout main'
alias mux="tmuxinator"
alias ng="npm list -g --depth=0 2>/dev/null"
alias nl="npm list --depth=0 2>/dev/null"
alias ping='prettyping --nolegend'
alias please='sudo $(fc -ln -1)'
alias rake="noglob rake"
alias vi='nvim'
alias weather='curl wttr.in'
alias yt='yt-dlp -x --audio-format "mp3"'

DISABLE_AUTO_UPDATE=true
DISABLE_UPDATE_PROMPT=true
VI_MODE_SET_CURSOR=true
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC='true'
ZSH_DISABLE_COMPFIX=true
ZSH_THEME="powerlevel10k/powerlevel10k"

source ~/.p10k.zsh

plugins=(
  colorize
  gitfast
  man
  node
  npm
  rake-fast
  vi-mode
  z
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting
)

[ -f ~/.oh-my-zsh/oh-my-zsh.sh ] && source ~/.oh-my-zsh/oh-my-zsh.sh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f /opt/homebrew/opt/chruby/share/chruby/chruby.sh ] && source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
[ -f /usr/local/opt/chruby/share/chruby/chruby.sh ] && source /usr/local/opt/chruby/share/chruby/chruby.sh
[ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
if [ -f /opt/homebrew/opt/chruby/share/chruby/chruby.sh ]; then
  source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
  source /opt/homebrew/opt/chruby/share/chruby/auto.sh
  chpwd_functions+=("chruby_auto")
fi
if [ -f /usr/local/opt/chruby/share/chruby/chruby.sh ]; then
  source /usr/local/opt/chruby/share/chruby/chruby.sh
  source /usr/local/opt/chruby/share/chruby/auto.sh
  chpwd_functions+=("chruby_auto")
fi

autoload -U compinit && compinit
setopt AUTO_PUSHD
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' cache-path ~/.zsh/cache
zstyle ':completion:*' use-cache on
zstyle ':completion:*:directory-stack' list-colors '=(#b) #([0-9]#)*( *)==95=38;5;12'

if [[ -n "$TMUX" ]]; then
  bindkey '^A' beginning-of-line
  bindkey '^E' end-of-line
fi
bindkey '^[[Z' autosuggest-accept
bindkey '^f' fzf-cd-widget
bindkey '^j' history-substring-search-down
bindkey '^k' history-substring-search-up
bindkey -M vicmd "j" down-line-or-beginning-search
bindkey -M vicmd "k" up-line-or-beginning-search

function upgrade_custom_oh_my_zsh() {
  example='example'
  custom_type=$1
  for custom_plugin_or_theme in $ZSH/custom/$custom_type/*; do
    if test "${custom_plugin_or_theme#*$example}" = "$custom_plugin_or_theme"
    then
      printf "Upgrading $custom_plugin_or_theme...\n"
      cd $custom_plugin_or_theme && git pull --stat && cd -
    fi
  done
}

function upgrade_all_oh_my_zsh() {
  upgrade_custom_oh_my_zsh 'plugins'
  upgrade_custom_oh_my_zsh 'themes'
  omz update
}

function ranger() {
  local IFS=$'\t\n'
  local tempfile="$(mktemp -t tmp.XXXXXX)"
  local ranger_cmd=(
    command
    ranger
    --cmd="map Q chain shell echo %d > "$tempfile"; quitall"
  )

  ${ranger_cmd[@]} "$@"
  if [[ -f "$tempfile" ]] && [[ "$(cat -- "$tempfile")" != "$(echo -n `pwd`)" ]]; then
    cd -- "$(cat "$tempfile")" || return
  fi
  command rm -f -- "$tempfile" 2>/dev/null
}

function lg() {
  export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

  lazygit "$@"

  if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
    cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
    rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
  fi
}

function ssh() {
  case $1 in
    mini)
      command ssh teddys-mac-mini.local
      ;;
    work)
      command ssh teddys-shopify-macBook-pro.local
      ;;
    mbp)
      command ssh teddys-macbook-pro.local
      ;;
    nicole)
      command ssh nicolepaik@nicoles-macbook-air.local
      ;;
    spin)
      command ssh $(spin show --output fqdn)
      ;;
    *)
      command ssh $@
      ;;
  esac
}

function tmux() {
  case $1 in
    start)
      command tmux new-session -d -s $2
      command tmux new-window -n Terminal
      command tmux kill-window -t 0
      command tmux new-window -d -n Editor
      command tmux new-window -d -n Server
      command tmux select-window -t 0
      ;;
    *)
      command tmux $@
      ;;
  esac
}

function killport() {
  lsof -i tcp:$1 | awk 'NR!=1 {print $2}' | xargs kill -9
}

function branch() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git for-each-ref --color --sort=-committerdate \
      refs/heads/ \
      --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) | (%(color:green)%(committerdate:relative)%(color:reset)) %(color:bold)%(authorname)%(color:reset) - %(contents:subject)' | \
      fzf --ansi | \
      cut -f2 -d'*' | \
      cut -f1 -d'|' | \
      xargs)

    if [ ! -z "$branch" ] ; then
      git checkout "$branch"
    fi
  else
    echo 'ERROR: Not a git repository'
  fi
}

function cob() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --color --sort=-committerdate \
      --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) | (%(color:green)%(committerdate:relative)%(color:reset)) %(color:bold)%(authorname)%(color:reset) - %(contents:subject)' -r | \
      fzf --ansi | \
      sed "s/origin\///g" | \
      cut -f1 -d'|' | \
      xargs)

    if [ ! -z "$branch" ] ; then
      git checkout "$branch"
    fi
  else
    echo 'ERROR: Not a git repository'
  fi
}

function upstream() {
  branch=$(git rev-parse --abbrev-ref HEAD)
  if [ ! -z "$branch" ] ; then
    git branch --set-upstream-to=origin/$branch $branch
  fi
}

tinty_source_shell_theme() {
  newer_file=$(mktemp)
  tinty $@
  subcommand="$1"

  if [ "$subcommand" = "apply" ] || [ "$subcommand" = "init" ]; then
    tinty_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tinted-theming/tinty"

    while read -r script; do
      . "$script"
    done < <(find "$tinty_data_dir" -maxdepth 1 -type f -name "*.sh" -newer "$newer_file")

    unset tinty_data_dir
  fi

  unset subcommand
}

if [ -n "$(command -v 'tinty')" ]; then
  tinty_source_shell_theme "init" > /dev/null

  alias tinty=tinty_source_shell_theme
fi

if [ -f /opt/dev/dev.sh ]; then
[[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }
fi
[[ -x /usr/local/bin/brew ]] && eval $(/usr/local/bin/brew shellenv)
[[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

# pnpm
export PNPM_HOME="/Users/teddyhwang/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

if command -v gh &> /dev/null; then
  eval "$(gh completion -s zsh)"
fi
if command -v atuin &> /dev/null; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

eval "$(zoxide init zsh)"

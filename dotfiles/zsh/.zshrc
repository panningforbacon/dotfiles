## ~/.zshrc — interactive shell config
##
## ---------------------------------------------------------------------------
## LOAD ORDER:
## options → history → completion → plugins(antidote) → mise → zoxide → fzf → prompt(starship)
## Prompt is LAST; syntax-highlighting plugin is LAST within the plugin list.
## ---------------------------------------------------------------------------

## ---------------------------------------------------------------------------
## 0. PATH & ENVIRONMENT
## ---------------------------------------------------------------------------
## Homebrew: on Apple Silicon it's /opt/homebrew, on Intel it's /usr/local.
## `brew shellenv` sets PATH/MANPATH/etc. correctly for either.

eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

# export EDITOR="nvim"                 # default editor for git, etc.
# export VISUAL="$EDITOR"
# export PAGER="less"
# export LANG="en_US.UTF-8"
# path=("$HOME/.local/bin" $path)      # zsh array; dedupe handled by typeset below
# typeset -U path PATH                 # -U = keep PATH entries unique

## ---------------------------------------------------------------------------
## 1. SHELL OPTIONS (setopt)
## ---------------------------------------------------------------------------
## Full list: `man zshoptions`. These are the high-value, low-surprise ones.

setopt AUTO_CD                # `foo` == `cd foo` if foo is a directory
setopt INTERACTIVE_COMMENTS   # allow # comments when typing interactively

# setopt EXTENDED_GLOB        # advanced globbing: ^, ~, #, (patterns)
# setopt GLOB_DOTS            # let globs match dotfiles without explicit .
# setopt NUMERIC_GLOB_SORT    # sort globbed numbers numerically (file2 < file10)
# setopt NO_CASE_GLOB         # case-insensitive globbing
# setopt CORRECT              # offer spelling correction for commands
# unsetopt BEEP               # stop the terminal bell

## ---------------------------------------------------------------------------
## 2. HISTORY
## ---------------------------------------------------------------------------

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000                # lines kept in memory this session
SAVEHIST=50000                # lines written to HISTFILE

setopt SHARE_HISTORY          # share history live across open shells
setopt HIST_IGNORE_DUPS       # don't record a line identical to the previous
setopt HIST_IGNORE_SPACE      # lines starting with a space aren't recorded
setopt HIST_REDUCE_BLANKS     # trim superfluous whitespace before saving

# setopt EXTENDED_HISTORY     # record timestamp + duration per command
# setopt HIST_IGNORE_ALL_DUPS # remove ALL older dups, not just consecutive
# setopt HIST_VERIFY          # on history expansion, show before running
# setopt INC_APPEND_HISTORY   # append immediately (redundant w/ SHARE_HISTORY)

## ---------------------------------------------------------------------------
## 3. COMPLETION
## ---------------------------------------------------------------------------
## compinit builds the completion system. -C skips the security audit for
## speed (safe on a single-user machine you control). Drop -C if paranoid.
autoload -Uz compinit && compinit -C

## Case-insensitive + partial-word matching (Tab completes "Doc" -> "Documents").
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# zstyle ':completion:*' menu select                       # arrow-key menu
# zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"  # colorized matches
# zstyle ':completion:*' group-name ''                     # group by type
# zstyle ':completion:*:descriptions' format '%B%d%b'      # bold group headers
# zstyle ':completion:*' rehash true                       # notice new binaries

## ---------------------------------------------------------------------------
## 4. KEYBINDINGS
## ---------------------------------------------------------------------------
bindkey -e                    # emacs keymap (Ctrl-A/E/R). Use `-v` for vi mode.

# bindkey '^[[A' history-substring-search-up      # ↑ = search history by prefix
# bindkey '^[[B' history-substring-search-down    # (needs the plugin, below)
# bindkey '^[[1;5C' forward-word                   # Ctrl-→ jump word
# bindkey '^[[1;5D' backward-word                  # Ctrl-← jump word

## ---------------------------------------------------------------------------
## 5. PLUGINS (via antidote)
## ---------------------------------------------------------------------------
## antidote reads ~/.zsh_plugins.txt, compiles it to a single sourced bundle,
## and caches it. Rebuild happens automatically when the .txt changes.
## The plugin LIST ORDER is what matters — see .zsh_plugins.txt for why
## fast-syntax-highlighting must be last.
source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
antidote load "$HOME/.zsh_plugins.txt"

## autosuggestions tuning (plugin active; these are optional overrides):
# ZSH_AUTOSUGGEST_STRATEGY=(history completion)  # where suggestions come from
# ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"          # dim gray suggestion color
# bindkey '^ ' autosuggest-accept                 # Ctrl-Space to accept

## ---------------------------------------------------------------------------
## 6. TOOL INTEGRATIONS  (each hooks the shell via an eval/source line)
## ---------------------------------------------------------------------------
## mise — runtime version manager. Activates before the prompt so version
## segments render correctly. Wraps uv for Python; uv still owns packaging.
eval "$(mise activate zsh)"

## zoxide — frecency-based `cd`. Adds `z <partial>` to jump around.
eval "$(zoxide init zsh)"
# eval "$(zoxide init --cmd cd zsh)"   # replace `cd` itself with zoxide

## fzf — fuzzy finder. Provides Ctrl-R (history), Ctrl-T (files), Alt-C (cd).
source <(fzf --zsh)
# export FZF_DEFAULT_OPTS="--height 40% --layout reverse --border"
# export FZF_CTRL_T_COMMAND="fd --type f --hidden --exclude .git"  # needs fd

## ---------------------------------------------------------------------------
## 7. ALIASES & FUNCTIONS
## ---------------------------------------------------------------------------
alias ll="ls -lah"
alias reload="exec zsh"        # restart shell to reload config cleanly

# alias g="git"
# alias gs="git status -sb"
# alias gl="git log --oneline --graph --decorate -20"
# alias ..="cd .."
# alias ...="cd ../.."
# alias serve="python3 -m http.server"
#
# # Function example: mkdir + cd in one step.
# mkcd() { mkdir -p "$1" && cd "$1"; }
#
# # Function example: extract most archive types.
# extract() {
#   case "$1" in
#     *.tar.gz|*.tgz) tar xzf "$1" ;;
#     *.tar.bz2)      tar xjf "$1" ;;
#     *.zip)          unzip "$1"   ;;
#     *) echo "extract: unsupported: $1" ;;
#   esac
# }

## ---------------------------------------------------------------------------
## 8. PROMPT — starship. MUST BE LAST.
## ---------------------------------------------------------------------------
## Starship reads ~/.config/starship.toml. Init goes last so nothing later
## clobbers the prompt hooks.
eval "$(starship init zsh)"

## ---------------------------------------------------------------------------
## 9. LOCAL / MACHINE-SPECIFIC OVERRIDES  (keep out of version control)
## ---------------------------------------------------------------------------
## Put secrets, work-only paths, and per-machine tweaks here. Gitignore it.
# [[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

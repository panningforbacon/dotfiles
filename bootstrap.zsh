#!/bin/zsh -f
# bootstrap.zsh: the target of the pasted command.
#
#   /bin/zsh -f -c "$(curl -fsSL <raw URL of this file>)" bootstrap [options]
#
# A loader, not the provisioner. Options pass through to bin/provision.
#
# idiom: main wrapper. Everything is a function and the only top-level
# command is the last line. The script arrives through a command
# substitution, so a download cut short would otherwise run as far as it got.
#
# at run: defines four functions, then calls main "$@" on the last line.
# calls:
#   main
#   ├── _bootstrap_log
#   ├── _bootstrap_ensure_clt
#   │   └── _bootstrap_log
#   └── _bootstrap_clone
#       └── _bootstrap_log
# contract: main returns 0 after a check-mode DIFF and 1 after a FAIL.
#   Otherwise it does not return: exec replaces this process with
#   bin/provision, whose exit code becomes the pasted command's.
# globals: defines none. Reads DOTFILES_DIR, DOTFILES_REPO_URL,
#   DOTFILES_CLT_GIT, HOME and NO_COLOR from the environment.

# _bootstrap_log <STATUS> <subject> <message>
# A private copy of the log format; lib/log.zsh is not on disk until the
# clone succeeds.
_bootstrap_log() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  local -i fd=1
  local sgr=''
  case $1 in
    (FAIL)    fd=2; sgr=31 ;;
    (ACTION)  sgr='1;35' ;;
    (CHANGED) sgr=32 ;;
    (DIFF)    sgr=36 ;;
  esac
  local now
  strftime -s now '%H:%M:%S' $EPOCHSECONDS
  # idiom: ${(r:7:)1} right-pads $1 with spaces to 7 columns.
  # The [bootstrap] column is padded by hand to match lib/log.zsh.
  local line="$now  ${(r:7:)1}  [bootstrap]       $2: $3"
  # idiom: [[ -t $fd ]] is true when that file descripter is a terminal.
  # No color into pipes or files.
  if [[ -n $sgr && -t $fd && -z ${NO_COLOR:-} ]]; then
    line=$'\e['"${sgr}m${line}"$'\e[0m'
  fi
  print -r -u $fd -- "$line"
}

# _bootstrap_ensure_clt <path of the tools' git>
# Watches for the git binary, not `xcode-select -p`: git is what the clone
# needs, and -p may not be reliable mid-install.
# Never runs /usr/bin/git as a test; without the tools it is a stub that
# opens the install dialog by itself.
_bootstrap_ensure_clt() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  local clt_git=$1 output

  # Already installed.
  [[ -x $clt_git ]] && return 0

  # Opens the installer dialog.
  # Output captured: xcode-select's own note would break the log format.
  if ! output=$(xcode-select --install 2>&1); then
    # idiom: ${output##*$'\n'} strips the longest prefix that ends in a
    # newline, leaving the last line.
    _bootstrap_log FAIL 'Command Line Tools' \
      "could not start the installer (${${output##*$'\n'}:-no message}) — if an install is already running, wait for it to finish; then paste the command again"
    return 1
  fi

  # Wait for the install.
  # xcode-select returns at once and the dialog can be dismissed, so the
  # message has to say how to get out of the loop.
  _bootstrap_log ACTION 'Command Line Tools' \
    'Click Install in the dialog that just opened; this run continues by itself when the install finishes. If you closed the dialog, press Ctrl-C and paste the command again.'
  until [[ -x $clt_git ]]; do
    sleep 5
  done
}

# _bootstrap_clone <git> <url> <dir> <dir as shown to the user>
_bootstrap_clone() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  local git=$1 url=$2 dir=$3 shown=$4 output

  # Clone.
  # Output captured, so git's messages fits inside one FAIL line.
  # GIT_TERMINAL_PROMPT=0: git answers a wrong URL with a username prompt,
  # which with output hidden would look like a hang. This makes it a failure.
  if ! output=$(GIT_TERMINAL_PROMPT=0 $git clone --quiet -- $url $dir 2>&1); then
    _bootstrap_log FAIL "$shown" \
      "git clone failed (${${output##*$'\n'}:-no message}) — check the network connection, then paste the command again"
    return 1
  fi

  # Verify.
  # CHANGED is only logged for a change that was read back.
  if [[ ! -f $dir/bin/provision ]]; then
    _bootstrap_log FAIL "$shown" \
      "expected bin/provision in the clone, found none — check that $url is the dotfiles repository"
    return 1
  fi
  _bootstrap_log CHANGED "$shown" 'cloned — verified'
}

main() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  zmodload zsh/datetime    # strftime builtin and $EPOCHSECONDS

  # Settings.
  # idiom: ${VAR:-default}
  # the last two exist so tests can swap in a local repo and stub git.
  local dir=${DOTFILES_DIR:-$HOME/.dotfiles}
  local url=${DOTFILES_REPO_URL:-https://github.com/panningforbacon/dotfiles.git}
  local clt_git=${DOTFILES_CLT_GIT:-/Library/Developer/CommandLineTools/usr/bin/git}
  
  # idiom: ${dir/#$HOME/~} replaces a leading $HOME with a literal ~.
  local shown=${dir/#$HOME/'~'}

  # Checkout already here: run it as it stands.
  # No git on this path: nothing is pulled, and uncommitted edits run.
  # idiom: exec replaces this process, so bin/provision inherits stdin (the
  # keyboard) and its exit code becomes the pasted command's.
  # Run through /bin/zsh -f rather than directly, so a lost executable bit
  # cannot break the way in.
  if [[ -f $dir/bin/provision ]]; then
    exec /bin/zsh -f $dir/bin/provision "$@"
  fi

  # Check mode: report and leave.
  # Everything below is a change, so the missing checkout is the one finding.
  # idiom: ${@[(Ie)--check]} is the index of the argument that equals
  # --check, or 0 if there is none.
  if (( ${@[(Ie)--check]} )); then
    _bootstrap_log DIFF "$shown" 'no checkout — would change'
    return 0
  fi

  # Refuse a target that already holds something.
  # git would refuse too, with a message that names no remedy.
  # Never deleted from here: it may be the user's.
  # idiom: glob qualifiers. (N) no error if nothing matches, (D) include
  # dotfiles, ([1]) stop at the first match.
  local -a entries=( $dir/*(ND[1]) )
  if [[ -e $dir && ! -d $dir ]] || (( $#entries )); then
    _bootstrap_log FAIL "$shown" \
      'expected a checkout or an empty directory, found other files — move it aside or set DOTFILES_DIR to another path, then paste the command again'
    return 1
  fi

  # Install the tools, clone, hand off.
  _bootstrap_ensure_clt $clt_git || return 1
  _bootstrap_clone $clt_git $url $dir "$shown" || return 1
  exec /bin/zsh -f $dir/bin/provision "$@"
}

main "$@"
#!/bin/zsh -f
# bootstrap.zsh: the target of the pasted command (ADR-0003, architecture §3).
#
#   /bin/zsh -f -c "$(curl -fsSL <raw URL of this file>)" bootstrap [options]
#
# A loader, not the provisioner: it runs the checkout at $DOTFILES_DIR as it
# stands, or creates that checkout first. Options go to bin/provision.
#
# Everything is a function and the only top-level command is the last line.
# The script arrives through a command substitution, so a download cut short
# would otherwise run as far as it got.
# idiom: main wrapper. Nothing executes until the whole file has been read.

# The loader's own copy of the §8.5 line format: lib/log.zsh is not on disk
# until the clone succeeds (ADR-0003). Only the statuses the loader prints.
# _bootstrap_log <STATUS> <subject> <message>
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
  # idiom: ${(r:7:)1} right-pads $1 with spaces to 7 columns. The module
  # column is padded to 16 by hand, as lib/log.zsh would pad it.
  local line="$now  ${(r:7:)1}  [bootstrap]       $2: $3"
  if [[ -n $sgr && -t $fd && -z ${NO_COLOR:-} ]]; then
    line=$'\e['"${sgr}m${line}"$'\e[0m'
  fi
  print -r -u $fd -- "$line"
}

# _bootstrap_ensure_clt <path of the tools' git>
# Waits on the git binary rather than on `xcode-select -p`: it is what the
# clone needs, and whether -p can succeed mid-install is unverified (spike S-2).
# /usr/bin/git is never run as a test: without the tools it is a stub that
# opens the install dialog by itself.
_bootstrap_ensure_clt() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  local clt_git=$1 output
  [[ -x $clt_git ]] && return 0

  # Captured, because xcode-select's own note would break the line format.
  if ! output=$(xcode-select --install 2>&1); then
    # idiom: ${output##*$'\n'} strips the longest prefix that ends in a
    # newline, leaving the last line.
    _bootstrap_log FAIL 'Command Line Tools' \
      "could not start the installer (${${output##*$'\n'}:-no message}) — if an install is already running, wait for it to finish; then paste the command again"
    return 1
  fi
  # xcode-select returns at once and the dialog can be dismissed, so the
  # line has to say how to get out of the wait below.
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

  # Captured, so git's messages end up inside one FAIL line. With its output
  # hidden, a username prompt (git's answer to a wrong URL) would look like a
  # hang; GIT_TERMINAL_PROMPT=0 turns that prompt into a failure.
  if ! output=$(GIT_TERMINAL_PROMPT=0 $git clone --quiet -- $url $dir 2>&1); then
    _bootstrap_log FAIL "$shown" \
      "git clone failed (${${output##*$'\n'}:-no message}) — check the network connection, then paste the command again"
    return 1
  fi
  # CHANGED means read back (§8.5): the clone must hold what runs next.
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

  # idiom: ${VAR:-default}. The last two exist so tests can swap in a local
  # repository and a stub git; DOTFILES_DIR is the documented one (ADR-0003).
  local dir=${DOTFILES_DIR:-$HOME/.dotfiles}
  local url=${DOTFILES_REPO_URL:-https://github.com/panningforbacon/dotfiles.git}
  local clt_git=${DOTFILES_CLT_GIT:-/Library/Developer/CommandLineTools/usr/bin/git}
  # idiom: ${dir/#$HOME/~} replaces a leading $HOME with a literal ~.
  local shown=${dir/#$HOME/'~'}

  # An existing checkout runs as it stands: no git command on this path, so
  # nothing is pulled and uncommitted edits run (CR-6).
  # idiom: exec replaces this process, so bin/provision inherits stdin (the
  # keyboard) and its exit code becomes the pasted command's.
  # Run through /bin/zsh -f, the script's own shebang, so a lost executable
  # bit cannot break the one documented way in.
  if [[ -f $dir/bin/provision ]]; then
    exec /bin/zsh -f $dir/bin/provision "$@"
  fi

  # Check mode changes nothing and has no manual stops (FR-16.1), and both
  # steps below are changes, so the missing checkout is the one finding.
  # idiom: ${@[(Ie)--check]} is the index of the argument that equals
  # --check, or 0 if there is none.
  if (( ${@[(Ie)--check]} )); then
    _bootstrap_log DIFF "$shown" 'no checkout — would change'
    return 0
  fi

  # git would refuse to clone into a directory that holds anything, with a
  # message that names no remedy. Never deleted from here: it may be the user's.
  # idiom: glob qualifiers. (N) no error if nothing matches, (D) include
  # dotfiles, ([1]) stop at the first match.
  local -a entries=( $dir/*(ND[1]) )
  if [[ -e $dir && ! -d $dir ]] || (( $#entries )); then
    _bootstrap_log FAIL "$shown" \
      'expected a checkout or an empty directory, found other files — move it aside or set DOTFILES_DIR to another path, then paste the command again'
    return 1
  fi

  _bootstrap_ensure_clt $clt_git || return 1
  _bootstrap_clone $clt_git $url $dir "$shown" || return 1
  exec /bin/zsh -f $dir/bin/provision "$@"
}

main "$@"
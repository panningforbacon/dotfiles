#!/bin/zsh -f
# modules/defaults.zsh: the macOS settings stage (FR-10, docs/architecture.md §4).
# Sourced by bin/provision; not executed on its own.
#
# Sprint 1 manages one item, the screenshot folder (FR-10.4). The settings
# manifest (ADR-0006) arrives in a later sprint.

mod_defaults_run() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  log_start defaults 1

  local -i failed=0
  _defaults_screenshot_dir || failed=1

  log_finish
  return $failed
}

# --- private -----------------------------------------------------------------

_defaults_screenshot_dir() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  local dir=$HOME/Desktop/Screenshots
  # idiom: ${var/#pattern/repl} replaces a match anchored at the start, so
  # log lines show ~/… and never the account name (NFR-3).
  local shown=${dir/#$HOME/\~}

  # The path travels as an argument: converge runs each function in a
  # subshell, so arguments are the only state the three can share.
  converge 'Screenshots folder' present \
    "move aside whatever is at $shown, then re-run" \
    _defaults_dir_check _defaults_dir_apply _defaults_dir_verify $dir
}

# Prints the observed state; returns 0 only for a folder. -d follows symlinks,
# so a link to a folder counts as present: the user chose it, and nothing
# undeclared is modified (FR-14.2).
_defaults_dir_check() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  if [[ -d $1 ]]; then
    print -r -- present
  elif [[ -e $1 || -L $1 ]]; then
    # -e follows symlinks and so misses a dangling one; -L catches it.
    print -r -- 'not a folder'
    return 1
  else
    print -r -- missing
    return 1
  fi
}

# Refuses in its own words instead of leaning on mkdir's error, which differs
# between systems and would not say that the path was left alone (FR-14.2).
_defaults_dir_apply() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  if [[ ! -d $1 && ( -e $1 || -L $1 ) ]]; then
    print -r -- 'found something that is not a folder, left untouched'
    return 1
  fi
  # -p: no error if the folder appeared since the check, so an interrupted
  # run can be repeated (FR-14.3).
  mkdir -p -- $1 || return 1
  print -r -- created
}

_defaults_dir_verify() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  _defaults_dir_check $1
}
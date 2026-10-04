#!/bin/zsh -f
# modules/defaults.zsh: the macOS settings stage.
# Sourced by bin/provision; not executed on its own.
#
# For now it manages one item, the screenshot folder. The settings manifest
# arrives later.
#
# at source: defines the functions; runs nothing.
# calls:
#   mod_defaults_run
#   └── _defaults_screenshot_dir
#   passed by name to converge:
#   ├── _defaults_dir_check
#   ├── _defaults_dir_apply
#   └── _defaults_dir_verify
#       └── _defaults_dir_check
# outside: log_start, log_finish, converge.
# contract: mod_defaults_run returns 0 when no item failed, 1 otherwise.
# globals: defines none. Reads HOME.

mod_defaults_run() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  log_start defaults 1

  # idiom: local -i declares an integer.
  local -i failed=0
  _defaults_screenshot_dir || failed=1

  log_finish
  return $failed
}

# --- private -----------------------------------------------------------------

_defaults_screenshot_dir() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  local dir=$HOME/Desktop/Screenshots
  # Log lines show ~/… and never the account name.
  # idiom: ${var/#pattern/repl} replaces a match anchored at the start. \~ is
  # a literal tilde.
  local shown=${dir/#$HOME/\~}

  # The path travels as an argument: converge runs each function in a
  # subshell, so arguments are the only state the three can share.
  # idiom: zsh does not word-split an unquoted $dir, so a path with spaces
  # stays one argument.
  converge 'Screenshots folder' present \
    "move aside whatever is at $shown, then re-run" \
    _defaults_dir_check _defaults_dir_apply _defaults_dir_verify $dir
}

# Prints the observed state; returns 0 only for a folder. A link to a folder
# counts as present: the user chose it, and nothing undeclared is modified.
_defaults_dir_check() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  # idiom: -d is true for a directory, and follows symlinks.
  if [[ -d $1 ]]; then
  # idiom: print -r disables backslash escapes; -- ends the options.
    print -r -- present
  elif [[ -e $1 || -L $1 ]]; then
    # idiom: -e follows symlinks and so misses a dangling one; -L catches it.
    print -r -- 'not a folder'
    return 1
  else
    print -r -- missing
    return 1
  fi
}

# Refuses in its own words instead of leaning on mkdir's error, which differs
# between systems and would not say that the path was left alone.
_defaults_dir_apply() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  # Refuse.
  # idiom: inside [[ ]], parentheses group conditions.
  if [[ ! -d $1 && ( -e $1 || -L $1 ) ]]; then
    print -r -- 'found something that is not a folder, left untouched'
    return 1
  fi
  # Create.
  # -p: no error if the folder appeared since the check, so an interrupted
  # run can be repeated.
  mkdir -p -- $1 || return 1
  print -r -- created
}

_defaults_dir_verify() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  _defaults_dir_check $1
}
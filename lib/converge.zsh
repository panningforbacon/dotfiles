#!/bin/zsh -f
# lib/converge.zsh: check → apply → verify for one managed item.
# Sourced after lib/log.zsh; not executed on its own.
#
#   converge <subject> <desired> <remedy> <check_fn> <apply_fn> <verify_fn> [args...]
#
# check_fn, apply_fn and verify_fn receive [args...] and print one short
# phrase: the observed state, the past-tense result, the state found.
# Whether a FAIL stops the module is the module's call.
#
# at source: defines the functions; runs nothing.
# calls:
#   converge
#   ├── _converge_run
#   └── _converge_check_mode
# outside: log, and the check_fn, apply_fn and verify_fn named by the
#   caller.
# contract: converge logs exactly one line per item. It returns 0 for OK,
#   DIFF or CHANGED, and 1 for FAIL. It overwrites $REPLY.
# globals: reads CHECK_MODE.

converge() {
  emulate -L zsh
  # Check the arguments.
  local usage='call converge subject desired remedy check_fn apply_fn verify_fn [args...]'
  # idiom: inside (( )), a bare # is the argument count, the same as $#.
  if (( # < 6 )); then
    log FAIL converge "expected at least 6 arguments, got $# — $usage"
    return 1
  fi
  local subject=$1 desired=$2 remedy=$3 check_fn=$4 apply_fn=$5 verify_fn=$6
  shift 6

  # Validate the function names.
  # Done before anything runs, so a typo fails even under --check, which is
  # the first run of every live sequence.
  local fn
  for fn in "$check_fn" "$apply_fn" "$verify_fn"; do
    # idiom: $+functions[name] is 1 if a function by that name is defined.
    if (( ! $+functions[$fn] )); then
      log FAIL converge "'$fn' is not a function, for '$subject' — $usage"
      return 1
    fi
  done

  # Check.
  # Every status below is read through `if`, never `x=$(f); rc=$?`, so the
  # helper stays correct if functions ever run with ERR_RETURN.
  if _converge_run "$check_fn" "$@"; then
    log OK "$subject" "already $REPLY — skipping"
    return 0
  fi
  local observed=$REPLY

  # Check mode: report and leave.
  if _converge_check_mode; then
    log DIFF "$subject" "$observed — would change"
    return 0
  fi

  # Apply.
  local result rc
  if _converge_run "$apply_fn" "$@"; then
    result=$REPLY
  else
    rc=$?    # idiom: in an else branch, $? is still the if condition's status
    # idiom: ${name:-word} expands to word when name is unset or empty. An
    # apply_fn that fails without output is described by its exit status.
    log FAIL "$subject" "${REPLY:-$apply_fn exited $rc} — $remedy"
    return 1
  fi

  # Verify.
  # A command can succeed without its effect, so only the read-back may print CHANGED.
  if _converge_run "$verify_fn" "$@"; then
    log CHANGED "$subject" "$result — verified"
  else
    log FAIL "$subject" "expected $desired, found $REPLY — $remedy"
    return 1
  fi
}

# --- private -----------------------------------------------------------------

# _converge_run <fn> [args...]
# Runs fn, returns its status, and sets REPLY to its output on one line.
# stderr is captured too: nothing may reach the terminal except through log,
# and a failing command's own error is the best description of what failed.
# fn runs in a subshell (command substitution), so it cannot leave state
# behind for the next step; state is passed through [args...].
_converge_run() {
  emulate -L zsh
  local fn=$1 output
  shift
  # idiom: a plain assignment from $(...) has the exit status of the command
  # inside. Written as `local output=$(...)` it would have local's status,
  # which is why output is declared on the line above.
  if output=$("$fn" "$@" 2>&1); then
    # idiom: ${var//pattern/repl} replaces every match; $'\n' is a newline.
    REPLY=${output//$'\n'/; }    # idiom: ${var//pattern/repl} replaces every match
    return 0
  else
    local rc=$?
    REPLY=${output//$'\n'/; }
    return $rc
  fi
}

# Anything but unset, empty or 0 means check mode: a mistyped flag must err
# toward changing nothing.
_converge_check_mode() {
  emulate -L zsh
  [[ -n ${CHECK_MODE:-} && $CHECK_MODE != 0 ]]
}
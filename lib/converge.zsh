#!/bin/zsh -f
# lib/converge.zsh: check → apply → verify for one managed item
# (docs/architecture.md §6). Sourced after lib/log.zsh; not executed on its own.
#
#   converge <subject> <desired> <remedy> <check_fn> <apply_fn> <verify_fn> [args...]
#
# check_fn, apply_fn and verify_fn receive [args...] and print one short
# phrase: the observed state, the past-tense result, the state found.
# Each item yields exactly one log line (CR-18). Returns 0 for OK, DIFF or
# CHANGED, and 1 for FAIL; whether a FAIL stops the module is the module's call.

converge() {
  emulate -L zsh
  local usage='call converge subject desired remedy check_fn apply_fn verify_fn [args...]'
  if (( # < 6 )); then
    log FAIL converge "expected at least 6 arguments, got $# — $usage"
    return 1
  fi
  local subject=$1 desired=$2 remedy=$3 check_fn=$4 apply_fn=$5 verify_fn=$6
  shift 6

  # Validate names before anything runs, so a typo fails even under --check,
  # which is the first run of every live sequence.
  local fn
  for fn in "$check_fn" "$apply_fn" "$verify_fn"; do
    # idiom: $+functions[name] is 1 if a function by that name is defined.
    if (( ! $+functions[$fn] )); then
      log FAIL converge "'$fn' is not a function, for '$subject' — $usage"
      return 1
    fi
  done

  # Every status below is read through `if`, never `x=$(f); rc=$?`, so the
  # helper stays correct if functions ever run with ERR_RETURN (ADR-0002).
  if _converge_run "$check_fn" "$@"; then
    log OK "$subject" "already $REPLY — skipping"
    return 0
  fi
  local observed=$REPLY

  if _converge_check_mode; then
    log DIFF "$subject" "$observed — would change"
    return 0
  fi

  local result rc
  if _converge_run "$apply_fn" "$@"; then
    result=$REPLY
  else
    rc=$?    # in an else branch, $? is still the status of the if condition
    log FAIL "$subject" "${REPLY:-$apply_fn exited $rc} — $remedy"
    return 1
  fi

  # A command can succeed without its effect (FR-10.2), so only the read-back
  # may print CHANGED.
  if _converge_run "$verify_fn" "$@"; then
    log CHANGED "$subject" "$result — verified"
  else
    log FAIL "$subject" "expected $desired, found $REPLY — $remedy"
    return 1
  fi
}

# --- private -----------------------------------------------------------------

# _converge_run <fn> [args...]: runs fn, returns its status, and sets REPLY to
# its output on one line. stderr is captured too: nothing may reach the
# terminal except through log (FR-15.4), and a failing command's own error is
# the best description of what failed.
# fn runs in a subshell (command substitution), so it cannot leave state
# behind for the next step; pass state through [args...].
_converge_run() {
  emulate -L zsh
  local fn=$1 output
  shift
  if output=$("$fn" "$@" 2>&1); then
    REPLY=${output//$'\n'/; }    # idiom: ${var//pattern/repl} replaces every match
    return 0
  else
    local rc=$?
    REPLY=${output//$'\n'/; }
    return $rc
  fi
}

# Anything but unset, empty or 0 means check mode: a mistyped flag must err
# toward changing nothing (FR-16.1).
_converge_check_mode() {
  emulate -L zsh
  [[ -n ${CHECK_MODE:-} && $CHECK_MODE != 0 ]]
}
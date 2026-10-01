#!/bin/zsh -f
# lib/log.zsh: the only code that prints (ADR-0009, docs/architecture.md §7).
# Sourced by bin/provision; not executed on its own.
#
#   log_start <module> <item-count>     ▶ header; sets LOG_MODULE
#   log <STATUS> <subject> <message>    every other line
#   log_finish                          ■ header with LOG_MODULE's counts
#
# An empty subject prints the message alone, for the compact settings form.

zmodload zsh/datetime    # strftime builtin and $EPOCHSECONDS: no `date` process per line

# Status → "fd:SGR:counter". SGR is the ANSI color code; an empty field means
# no color or no counter. Adding a status is one row here plus one in §8.5.
typeset -gA _LOG_STATUS=(
  OK       '1:2:ok'
  CHANGED  '1:32:changed'
  DIFF     '1:36:would_change'
  FAIL     '2:31:failed'
  WARN     '1:33:'
  ACTION   '1:1;35:'
  NOTE     '1::'
)

# Headers are pre-padded to the status width so their alignment does not
# depend on the locale counting ▶ as one character or three bytes.
typeset -g _LOG_START_TAG='▶      '
typeset -g _LOG_FINISH_TAG='■      '
typeset -g _LOG_HEADER_SGR='1'

typeset -g  LOG_MODULE=provision    # lines outside any module (e.g. the summary) set this directly
typeset -gA LOG_COUNTS              # "module:counter" → count; read by log_finish and the run summary

log_start() {
  emulate -L zsh
  # <-> is a zsh glob that matches any non-negative integer.
  if (( # != 2 )) || [[ $2 != <-> ]]; then
    _log_misuse "log_start got '$*'" "call log_start <module> <item-count>"
    return 1
  fi
  LOG_MODULE=$1
  local row
  for row in ${(v)_LOG_STATUS}; do
    # ${row##*:} strips the longest prefix ending in ':', leaving the counter.
    [[ -n ${row##*:} ]] && LOG_COUNTS[${LOG_MODULE}:${row##*:}]=0
  done
  _log_emit 1 $_LOG_HEADER_SGR $_LOG_START_TAG "start — $2 items"
}

log() {
  emulate -L zsh
  if (( # != 3 )); then
    _log_misuse "expected 3 arguments, got $#" "call log STATUS subject message"
    return 1
  fi
  # Not `status`: in zsh that is a read-only alias of $?.
  local log_status=$1 subject=$2 message=$3
  local row=${_LOG_STATUS[$log_status]-}
  if [[ -z $row ]]; then
    _log_misuse "unknown status '$log_status' for '$subject'" "use one of ${(j:, :)${(@ok)_LOG_STATUS}}"
    return 1
  fi
  # (@s.:.) splits on ':' and keeps empty fields, which NOTE's row relies on.
  local -a fields=( "${(@s.:.)row}" )
  local fd=$fields[1] sgr=$fields[2] counter=$fields[3]
  [[ -n $counter ]] && _log_count $counter
  if [[ -n $subject ]]; then
    _log_emit $fd "$sgr" $log_status "$subject: $message"
  else
    _log_emit $fd "$sgr" $log_status "$message"
  fi
}

log_finish() {
  emulate -L zsh
  local module=$LOG_MODULE
  # ${module}:changed, never $module:changed: zsh reads an unbraced $module:c…
  # or $module:f… as a history modifier, so the lookup would silently miss.
  _log_emit 1 $_LOG_HEADER_SGR $_LOG_FINISH_TAG \
    "finish — ${LOG_COUNTS[${module}:changed]:-0} changed · ${LOG_COUNTS[${module}:ok]:-0} ok · ${LOG_COUNTS[${module}:failed]:-0} failed"
}

# --- private -----------------------------------------------------------------

# A broken call to the logger is itself a failure, so a typo fails the run (FR-15.1).
_log_misuse() {
  emulate -L zsh
  _log_count failed
  _log_emit 2 31 FAIL "log: $1 — $2"
}

_log_count() {
  emulate -L zsh
  local key="${LOG_MODULE}:$1"
  # Plain assignment, not (( LOG_COUNTS[$key]++ )): a post-increment from 0
  # evaluates to 0, which (( )) reports as failure.
  LOG_COUNTS[$key]=$(( ${LOG_COUNTS[$key]:-0} + 1 ))
}

# _log_emit <fd> <sgr> <tag> <text>
_log_emit() {
  emulate -L zsh
  local fd=$1 sgr=$2 tag=$3 text=$4
  _log_now;              local now=$REPLY
  _log_pad 7  $tag;      local tag_col=$REPLY
  _log_pad 16 "[$LOG_MODULE]"; local module_col=$REPLY
  local line="$now  $tag_col  $module_col  $text"
  if [[ -n $sgr ]] && _log_color_on $fd; then
    line=$'\e['"${sgr}m${line}"$'\e[0m'
  fi
  # print -r: no backslash escapes, so messages print exactly as given.
  print -r -u $fd -- "$line"
}

# Right-pads to a width but never truncates; zsh's ${(r:n:)x} would cut long names.
# Returns through $REPLY (zsh convention) to avoid a subshell per column.
_log_pad() {
  emulate -L zsh
  if (( ${#2} < $1 )); then
    REPLY=${(r:$1:)2}
  else
    REPLY=$2
  fi
}

_log_now() {
  emulate -L zsh
  strftime -s REPLY '%H:%M:%S' $EPOCHSECONDS
}

# Color per stream (FR-15.7): only on a terminal, and only if NO_COLOR is unset or empty.
_log_color_on() {
  emulate -L zsh
  [[ -t $1 && -z ${NO_COLOR:-} ]]
}
#!/usr/bin/env bash
# logging.sh — structured logging for shell scripts
#
# SOURCING:
#   source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
#
# CONFIGURATION (set before sourcing, or export in environment):
#   LOG_LEVEL   0=debug 1=info 2=warn 3=error 4=silent  (default: 1)
#   NO_COLOR    set to any value to disable ANSI color
#   LOG_FILE    path to append logs to (optional; terminal output unaffected)
#
# EXAMPLES:
#
#   # Basic levels — message goes to stdout (debug, info) or stderr (warn, error)
#   log_debug "resolving symlink: $target"
#   log_info  "installing packages"
#   log_warn  "config file not found, using defaults"
#   log_error "failed to write to $dest"
#
#   # Multi-word arguments are fine; no need to quote into a single string
#   log_info "backing up" "$HOME/.zshrc" "→" "$backup_path"
#
#   # die: log a FATAL message to stderr and exit (default exit code: 1)
#   [[ -d "$HOME" ]] || die "HOME directory does not exist: $HOME"
#
#   # die with an explicit exit code
#   command -v git &>/dev/null || die 127 "git is not installed"
#
#   # Suppress all output for a quiet install
#   LOG_LEVEL=4 source logging.sh
#
#   # Enable debug output at runtime (e.g. driven by a --verbose flag)
#   [[ "${VERBOSE-}" == "1" ]] && LOG_LEVEL=0
#
#   # Capture logs to a file while still printing to the terminal
#   LOG_FILE="$HOME/.local/log/install.log" source logging.sh

# ── level constants ────────────────────────────────────────────────────────────
readonly _LOG_DEBUG=0
readonly _LOG_INFO=1
readonly _LOG_WARN=2
readonly _LOG_ERROR=3
readonly _LOG_SILENT=4

# Default to INFO unless already set
: "${LOG_LEVEL:=0}"

# ── color setup ───────────────────────────────────────────────────────────────
# Disable color if: NO_COLOR is set, stdout isn't a TTY, or TERM=dumb
_log_use_color() {
  [[ -z "${NO_COLOR-}" ]] && [[ -t 1 ]] && [[ "${TERM-}" != "dumb" ]]
}

if _log_use_color; then
  _CLR_DEBUG='\033[0;36m'   # cyan
  _CLR_INFO='\033[0;32m'    # green
  _CLR_WARN='\033[0;33m'    # yellow
  _CLR_ERROR='\033[0;31m'   # red
  _CLR_DIM='\033[2m'        # dim (for caller context)
  _CLR_RESET='\033[0m'
else
  _CLR_DEBUG=''
  _CLR_INFO=''
  _CLR_WARN=''
  _CLR_ERROR=''
  _CLR_DIM=''
  _CLR_RESET=''
fi

# ── internal write function ───────────────────────────────────────────────────
# Usage: _log_write <fd> <color> <label> <caller_info> <message>
_log_write() {
  local fd="$1" color="$2" label="$3" caller="$4"
  shift 4
  local msg="$*"

  local line
  printf -v line "%b%-5s%b %b%s%b %s" \
    "$color" "$label" "$_CLR_RESET" \
    "$_CLR_DIM" "$caller" "$_CLR_RESET" \
    "$msg"

  # Write to fd (1=stdout, 2=stderr)
  echo -e "$line" >&"$fd"

  # Mirror to log file if configured (strip ANSI for file output)
  if [[ -n "${LOG_FILE-}" ]]; then
    echo "$label $caller $msg" >> "$LOG_FILE"
  fi
}

# ── caller context ────────────────────────────────────────────────────────────
# Returns "filename:lineno" of the call site (two frames up the stack)
_log_caller() {
  # Frame 0 = _log_caller, frame 1 = log_*, frame 2 = call site
  local file="${BASH_SOURCE[2]:-unknown}"
  local line="${BASH_LINENO[1]:-0}"
  # Trim to basename for brevity
  echo "(${file##*/}:${line})"
}

# ── public level functions ────────────────────────────────────────────────────

log_debug() {
  (( LOG_LEVEL <= _LOG_DEBUG )) || return 0
  _log_write 1 "$_CLR_DEBUG" "DEBUG" "$(_log_caller)" "$@"
}

log_info() {
  (( LOG_LEVEL <= _LOG_INFO )) || return 0
  _log_write 1 "$_CLR_INFO" "INFO" "$(_log_caller)" "$@"
}

log_warn() {
  (( LOG_LEVEL <= _LOG_WARN )) || return 0
  _log_write 2 "$_CLR_WARN" "WARN" "$(_log_caller)" "$@"
}

log_error() {
  (( LOG_LEVEL <= _LOG_ERROR )) || return 0
  _log_write 2 "$_CLR_ERROR" "ERROR" "$(_log_caller)" "$@"
}

# ── die: log error and exit ───────────────────────────────────────────────────
# Usage: die [exit_code] <message>
#   If first arg is numeric, used as exit code; otherwise defaults to 1.
die() {
  local exit_code=1
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    exit_code="$1"
    shift
  fi
  _log_write 2 "$_CLR_ERROR" "FATAL" "$(_log_caller)" "$@"
  exit "$exit_code"
}

# ── ERR trap ──────────────────────────────────────────────────────────────────
# Fires on any command that exits non-zero (requires `set -e` or `set -o errexit`).
# Reports the failed command and its exit code with full caller context.
#
# NOTE: trap ERR does NOT fire inside:
#   - conditions:      if some_cmd; then ...
#   - negated cmds:    ! some_cmd
#   - subshells with their own trap
# This is bash's ERR trap semantics — not a bug here, just reality.
_log_err_trap() {
  local exit_code=$?
  local failed_cmd="${BASH_COMMAND}"
  local file="${BASH_SOURCE[1]:-unknown}"
  local line="${BASH_LINENO[0]:-0}"
  _log_write 2 "$_CLR_ERROR" "FATAL" "(${file##*/}:${line})" \
    "command failed (exit ${exit_code}): ${failed_cmd}"
}

# Activate the trap — comment this out if you want manual control
trap '_log_err_trap' ERR
# -----------------------------------------------------------------------------
# Logging functions
# -----------------------------------------------------------------------------

_CLR_RESET="\033[0m"
_CLR_BOLD="\033[1m"
_CLR_RED="\033[0;31m"
_CLR_GREEN="\033[0;32m"
_CLR_YELLOW="\033[0;33m"
_CLR_CYAN="\033[0;36m"
_CLR_DIM="\033[2m"

debug() {
  printf "${_CLR_DIM}${_CLR_BOLD}[DEBUG]${_CLR_RESET} %s\n" "$*"
}

info() {
  printf "${_CLR_CYAN}${_CLR_BOLD}[INFO]${_CLR_RESET}  %s\n" "$*"
}

warn() {
  printf "${_CLR_YELLOW}${_CLR_BOLD}[WARN]${_CLR_RESET}  %s\n" "$*"
}

error() {
  printf "${_CLR_RED}${_CLR_BOLD}[ERROR]${_CLR_RESET} %s\n" "$*"
}

die() {
  error "$*"; exit 1
}

dim() {
  printf "${_CLR_DIM}        %s${_CLR_RESET}\n" "$*"
}


# ── Section logging ────────────────────────────────────────────────────────────────────

_get_log_width() {
  local terminal_width
  local max_width=80
  local margin=2

  terminal_width=$(tput cols 2>/dev/null || echo "$max_width")

  local usable_width=$(( terminal_width - margin ))

  echo $(( usable_width < max_width ? usable_width : max_width ))
}

LOG_WIDTH=$(_get_log_width)

section() {
  local title="$*"
  local inner=$(( LOG_WIDTH - 2 ))
  local bar; bar="$(printf "%${inner}s" | tr ' ' '═')"  # repeat '═' to fill the width
  printf "\n"
  printf "╔%s╗\n" "$bar"
  printf "║  %-$(( inner - 2 ))s║\n" "$title"
  # printf "╚%s╝\n" "$bar"
  printf "╟%s╢\n" "$bar"
}

section_end() {
  local title="$*"
  local inner=$(( LOG_WIDTH - 2 ))
  local bar; bar="$(printf "%${inner}s" | tr ' ' '=')"
  printf "╟%s╢\n" "$bar"
  printf "║  %-$(( inner - 2 ))s║\n" "$title"
  printf "╚%s╝\n" "$bar"
  printf "\n"
}

log() {
  printf "%s\n" "$*"
}




# -----------------------------------------------------------------------------
# ERR trap
# Wire up in every script: trap 'err_trap' ERR
# -----------------------------------------------------------------------------
err_trap() {
  local exit_code=$?
  local line="${BASH_LINENO[0]}"
  local cmd="${BASH_COMMAND}"
  local file="${BASH_SOURCE[1]:-unknown}"
  printf "${_CLR_RED}${_CLR_BOLD}[ERROR]${_CLR_RESET} command failed (exit %s)\n" "$exit_code" >&2
  printf "${_CLR_DIM}        file : %s\n"                                           "$file"      >&2
  printf "        line : %s\n"                                                      "$line"      >&2
  printf "        cmd  : %s${_CLR_RESET}\n"                                         "$cmd"       >&2
}


# ── Guard Clauses ────────────────────────────────────────────────────────────────────

# require_cmd <cmd> — fail loudly if a command is not on PATH
require_cmd() {
  command -v "$1" &>/dev/null \
    || fail "Required command not found: '$1'. Check your dependency order."
}
 
# command_exists <cmd> — boolean, no side effects
command_exists() {
  command -v "$1" &>/dev/null
}
 
# require_macos — fail if not running on macOS
require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "This script must be run on macOS."
}
 
# require_file <path> — fail if a required file is missing
require_file() {
  [[ -f "$1" ]] || fail "Required file not found: $1"
}

#!/bin/zsh -f
# modules/preflight.zsh: refuses unsupported hardware and macOS versions
# before any stage changes the machine.
# Sourced by bin/provision; not executed on its own.
#
# This stage only reads. A refusal is a FAIL line plus return 2, in check
# mode too: it is not a manual stop, so it never becomes ACTION or DIFF.
#
# at source: defines two global arrays and the functions; runs nothing.
# calls:
#   mod_preflight_run
#   ├── _preflight_check_hardware
#   │   ├── _preflight_probe_arm64
#   │   └── _preflight_is_arm64
#   └── _preflight_check_macos
#       ├── _preflight_probe_product_version
#       ├── _preflight_macos_major
#       └── _preflight_macos_tier
# outside: log_start, log, log_finish.
# contract: mod_preflight_run returns 0 to continue, 2 to refuse. Helpers
#   answer through $REPLY.
# globals: defines and reads PREFLIGHT_VERIFIED_MAJORS and
#   PREFLIGHT_TOLERATED_MAJORS.
 
# The supported tiers. A major version moves to the verified tier only after
# M4 verification passes on it; that move is an edit here.
# idiom: typeset -ga declares an array (-a) that is global (-g) even if this
# file is sourced from inside a function.
typeset -ga PREFLIGHT_VERIFIED_MAJORS=( 27 )
typeset -ga PREFLIGHT_TOLERATED_MAJORS=( 26 )

mod_preflight_run() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  log_start preflight 2

  # Both checks always run, so a refused Mac sees every reason in one run.
  # idiom: local -i declares an integer.
  local -i refused=0
  _preflight_check_hardware || refused=1
  _preflight_check_macos    || refused=1

  log_finish
  (( refused )) && return 2
  return 0
}

# --- private -----------------------------------------------------------------

_preflight_check_hardware() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  _preflight_probe_arm64
  if _preflight_is_arm64 "$REPLY"; then
    log OK 'Apple Silicon' 'arm64 — supported'
  else
    log FAIL 'Apple Silicon' 'expected arm64, found Intel — this project supports Apple Silicon only'
    return 1
  fi
}

_preflight_check_macos() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  _preflight_probe_product_version
  local version=$REPLY

  # Parse the major version.
  if ! _preflight_macos_major "$version"; then
    log FAIL macOS "could not read a version from sw_vers (got '$version') — run /usr/bin/sw_vers -productVersion and check what it prints"
    return 1
  fi
  local -i major=$REPLY

  # Report by tier.
  _preflight_macos_tier $major
  # idiom: a case pattern may be written (pattern), with the opening
  # parenthesis as well as the closing one.
  case $REPLY in
    (verified)
      log OK macOS "$version — verified tier"
      ;;
    (tolerated)
      log WARN macOS "$version is in the tolerated tier — unverified, continuing"
      ;;
    (*)
      # idiom: ${(on)array} sorts (o) numerically (n); ${(j: or :)array}
      # joins the elements with " or ".
      local -a supported=( ${(on)PREFLIGHT_VERIFIED_MAJORS} ${(on)PREFLIGHT_TOLERATED_MAJORS} )
      supported=( ${(on)supported} )
      local remedy='update macOS in System Settings, then re-run'
      # idiom: $array[-1] is the last element, here the newest supported major.
      if (( major > supported[-1] )); then
        remedy='this macOS is newer than the project supports; it has to be verified first (see the README)'
      fi
      log FAIL macOS "expected ${(j: or :)supported}, found $version — $remedy"
      return 1
      ;;
  esac
}

# The two probes are the only places this module runs a command. Tests
# replace them; everything below them takes text and is pure.
# Both return through $REPLY, the zsh convention, and use absolute paths, so
# the answer cannot depend on what PATH holds.
 
# hw.optional.arm64 describes the hardware, not the calling process: it is 1
# on Apple Silicon even when the terminal runs under Rosetta, where
# `uname -m` reports x86_64. On Intel the key does not exist, so sysctl
# prints nothing on stdout and exits non-zero.
_preflight_probe_arm64() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  # idiom: a plain assignment from $(...) has the exit status of the command
  # inside, so || runs when sysctl fails.
  REPLY=$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null) || REPLY=''
}

_preflight_probe_product_version() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  REPLY=$(/usr/bin/sw_vers -productVersion 2>/dev/null) || REPLY=''
}

# _preflight_is_arm64 <sysctl output>
# Status 0 only for the exact answer 1.
_preflight_is_arm64() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  [[ $1 == 1 ]]
}

# _preflight_macos_major <sw_vers -productVersion output>
# Sets REPLY to the major version. Returns 1, with REPLY empty, for anything
# that is not a dotted number: a guess here would decide whether the run may
# proceed.
_preflight_macos_major() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL EXTENDED_GLOB
  REPLY=''
  # idiom: <-> is a glob for any non-negative integer; (…)# is "zero or
  # more of", which needs EXTENDED_GLOB. A [[ == ]] pattern must match the
  # whole string, so no anchors are needed.
  [[ $1 == <->(.<->)# ]] || return 1
  # idiom: ${var%%pattern} removes the longest matching suffix, here
  # everything from the first dot.
  REPLY=${1%%.*}
}

# _preflight_macos_tier <major>
# Sets REPLY to verified, tolerated or unsupported.
_preflight_macos_tier() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  # idiom: ${array[(Ie)value]} is a reverse subscript: the index of the
  # element exactly (e) equal to value, or 0 if there is none (I).
  if (( ${PREFLIGHT_VERIFIED_MAJORS[(Ie)$1]} )); then
    REPLY=verified
  elif (( ${PREFLIGHT_TOLERATED_MAJORS[(Ie)$1]} )); then
    REPLY=tolerated
  else
    REPLY=unsupported
  fi
}

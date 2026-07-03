#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib.sh"
 
trap 'err_trap' ERR


# ── Settings ────────────────────────────────────────────────────────────────────

readonly USE_XCODE_SELECT_ONLY=false
readonly INSTALLER_TIMEOUT_SECONDS=30
readonly CLT_DIR="/Library/Developer/CommandLineTools"


# ── Flags ────────────────────────────────────────────────────────────────────

force=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) force=true; shift ;;
    *) error "Unknown option: $1" >&2; exit 1 ;;
  esac
done


# ── Checks ────────────────────────────────────────────────────────────────────

installation_exists() {
  local expected="$CLT_DIR"
  local actual
  actual="$(xcode-select -p 2>/dev/null)" || return 1
  [[ "$actual" == "$expected" && -d "$actual" ]]
}


installation_works() {
  local clang_path
  clang_path="$(xcrun --find clang 2>/dev/null)" || return 1
  [[ "$clang_path" == "$CLT_DIR"/* ]] || return 1
  "$clang_path" --version &>/dev/null
}


# ── Install ────────────────────────────────────────────────────────────────────

_install_via_softwareupdate() {
  # Apple convention: this exact path signals softwareupdate to list CLT.
  # Path is fixed by Apple, so it can't go through mktemp.
  local placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  local su_stderr label

  su_stderr="$(mktemp)"

  touch "$placeholder"

  _cleanup() { rm -f "$placeholder" "$su_stderr"; }

  # Parse the 'Label:' field rather than the bullet line, and trust
  # softwareupdate's list order (newest last) instead of imposing a
  # version sort the labels don't reliably honor.
  label="$(softwareupdate --list 2>"$su_stderr" \
    | sed -nE 's/^[[:space:]]*\*?[[:space:]]*Label:[[:space:]]*(.*Command Line Tools.*)$/\1/p' \
    | tail -1)"

  if [[ -z "$label" ]]; then
    warn "No 'Command Line Tools' label found in softwareupdate list"
    debug "softwareupdate output: $(cat "$su_stderr")"
    _cleanup; return 1
  fi

  debug "softwareupdate label: $label"

  softwareupdate --install "$label" --agree-to-license || {
    warn "softwareupdate failed"
    _cleanup; return 1
  }
  _cleanup
}


_install_via_xcode_select() {
  local proc="Install Command Line Developer Tools"
  local waited=0

  xcode-select --install 2>/dev/null || true
  info "Please complete the installer dialog to continue..."

  # Phase 1: wait for the installer to actually launch (up to ~30s).
  while ! pgrep -q "$proc"; do
    if (( waited >= INSTALLER_TIMEOUT_SECONDS )); then
      warn "Installer never appeared — already installed, or launch failed"
      return 1
    fi
    sleep 2
    (( waited += 2 ))
  done

  # Phase 2: now that it's running, wait for it to exit, then verify.
  while pgrep -q "$proc"; do
    sleep 5
  done

  installation_exists || {
    warn "Installer exited but CLT directory absent — likely cancelled"
    return 1
  }
}


install() {
  if [[ "$USE_XCODE_SELECT_ONLY" == true ]]; then
    info "USE_XCODE_SELECT_ONLY is set; skipping softwareupdate method"
  else
    info "Attempting to install via softwareupdate..."
    if _install_via_softwareupdate; then
      return 0
    fi
    warn "Installation via softwareupdate failed."
  fi

  info "Attempting xcode-select installer..."
  if _install_via_xcode_select; then
    return 0
  fi

  if [[ "$USE_XCODE_SELECT_ONLY" == true ]]; then
    error "Installation failed (xcode-select method)"
  else
    error "Installation failed via both methods"
  fi
  return 1
}


# ── Uninstall ────────────────────────────────────────────────────────────────────

uninstall() {
  info "Uninstalling Xcode Command Line Tools..."

  # Reversible first, then the destructive part.
  sudo xcode-select --reset 2>/dev/null || warn "xcode-select --reset failed (non-fatal)"
  sudo rm -rf "$CLT_DIR"

  # Best-effort receipt cleanup; missing packages aren't an error.
  local pkg
  for pkg in \
    com.apple.pkg.CLTools_Executables \
    com.apple.pkg.CLTools_SDK_macOS \
    com.apple.pkg.CLTools_macOS_SDK \
    com.apple.pkg.DeveloperToolsCLI
  do
    sudo pkgutil --forget "$pkg" 2>/dev/null || true
  done

  # Assert the postcondition instead of trusting exit codes.
  installation_exists && die "Uninstall failed: $CLT_DIR still present"

  info "Uninstallation complete."
}


# ── Main ────────────────────────────────────────────────────────────────────

section "Xcode Command Line Tools Installation"
require_macos

info "Checking for existing installation..."

action_plan=""
if installation_exists; then
  info "Existing installation: exists"
  if installation_works; then
    info "Existing installation: works"
    if $force; then
      info "Argument -f/--force found. Forcing a fresh reinstall..."
      action_plan="FORCE_INSTALL"
    else
      action_plan="NO_INSTALL"
    fi
  else
    info "Existing installation: exists, but not working"
    info "Reinstalling..."
    action_plan="REINSTALL"
  fi
else
  info "No install found. Installing..."
  action_plan="INSTALL"
fi

case "$action_plan" in
  "FORCE_INSTALL"|"REINSTALL")
    uninstall || die "Uninstall failed"
    install || die "Install failed"
    installation_exists && installation_works || die "Install verification failed"
    ;;
  "INSTALL")
    install || die "Install failed"
    installation_exists && installation_works || die "Install verification failed"
    ;;
  "NO_INSTALL")
    ;;
esac

section_end "Xcode Command Line Tools installation complete"
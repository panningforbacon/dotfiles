#!/usr/bin/env bash
# =============================================================================
# modules/xcode.sh — Install / verify Xcode Command Line Tools
# =============================================================================

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"


# ── state detectors ───────────────────────────────────────────────────────────

_is_xcode_installed() {
  local path
  path="$(xcode-select -p 2>/dev/null)" || return 1
  [[ -d "$path" ]]
}

_is_xcode_working() {
  command -v clang &>/dev/null
}


# ── install / uninstall ───────────────────────────────────────────────────────

_uninstall_xcode_clt() {
  log_warn "Removing Xcode CLT at $(xcode-select -p 2>/dev/null || echo '<unknown>')..."
  sudo rm -rf "$(xcode-select -p 2>/dev/null)" 2>/dev/null || true
  sudo xcode-select --reset 2>/dev/null || true
  log_info "Xcode CLT removed."
}

_install_xcode_clt() {
  log_info "Triggering Xcode CLT install prompt..."
  xcode-select --install 2>/dev/null || true

  echo ""
  log_warn "Complete the install dialog that appeared, then press Enter to continue."
  read -r -p ""

  log_info "Accepting Xcode license..."
  sudo xcodebuild -license accept 2>/dev/null || true
}


# ── main ──────────────────────────────────────────────────────────────────────

log_info "====================================================================="
log_info "Starting Xcode CLT installation and verification..."
log_info "====================================================================="

# Determine action.
action="install"

if _is_xcode_installed; then
  if _is_xcode_working; then
    log_info "Xcode Command Line Tools is installed and appears to be working."
    echo ""
    echo "  [k] Keep existing         (skip, continue installer)"
    echo "  [r] Remove and reinstall  (force version reset)"
    echo "  [x] Cancel                (exit installer)"
    echo ""

    while true; do
      read -r -p "  Choose [k/r/x]: " choice
      case "$(echo "$choice" | tr '[:upper:]' '[:lower:]')" in
        k) action="skip";      break ;;
        r) action="reinstall"; break ;;
        x) action="cancel";    break ;;
        *) log_warn "Invalid choice. Enter k, r, or x." ;;
      esac
    done

  else
    log_warn "Xcode Command Line Tools appears to be installed but is not working."
    log_info "Action: will attempt uninstall and reinstall automatically."
    action="reinstall"
  fi

else
  log_info "Xcode Command Line Tools not found. Proceeding with fresh install."
fi

# Execute action.
case "$action" in
  skip)
    log_skip "Keeping existing Xcode CLT. Skipping install."
    exit 0
    ;;
  cancel)
    log_warn "Cancelled by user."
    exit 1
    ;;
  reinstall)
    _uninstall_xcode_clt
    _install_xcode_clt
    ;;
  install)
    _install_xcode_clt
    ;;
esac

# Verify outcome.
if _is_xcode_installed && _is_xcode_working; then
  log_info "Xcode CLT path: $(xcode-select -p)"
  log_info "clang: $(command -v clang) — $(clang --version 2>&1 | head -1)"
  log_info "Xcode CLT verified and ready."
else
  ! _is_xcode_installed && log_error "xcode-select path missing or directory not found."
  ! _is_xcode_working   && log_error "clang not found on PATH."
  die "Xcode CLT verification failed. Aborting."
fi
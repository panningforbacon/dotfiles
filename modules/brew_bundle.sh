#!usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib.sh"
 
trap 'err_trap' ERR


# ── Helpers ────────────────────────────────────────────────────────────────────

# brew_prefix — returns Homebrew prefix for this architecture
brew_prefix() {
  if [[ "$(uname -m)" == "arm64" ]]; then
    echo "/opt/homebrew"
  else
    echo "/usr/local"
  fi
}

# ensure_brew_on_path — makes `brew` available if not yet on PATH
ensure_brew_on_path() {
  if ! command_exists brew; then
    local prefix
    prefix="$(brew_prefix)"
    eval "$("$prefix/bin/brew" shellenv)" 2>/dev/null \
      || fail "Could not find Homebrew at $prefix. Run modules/homebrew.sh first."
  fi
}


# ── Main ────────────────────────────────────────────────────────────────────

section "Homebrew Bundle"
require_macos
ensure_brew_on_path
require_cmd brew

BREWFILE="$DOTFILES_DIR/Brewfile"
require_file "$BREWFILE"

# # Ensure the bundle tap is available (ships with modern Homebrew but guard anyway)
# if ! brew tap | grep -q "^homebrew/bundle$"; then
#   info "Tapping homebrew/bundle..."
#   brew tap homebrew/bundle
# fi

info "Installing from Brewfile: $BREWFILE"

# --no-lock    — don't write a Brewfile.lock.json; lock files belong in
#                application repos, not dotfiles.
# --no-upgrade — do not upgrade packages that are already installed.
#                Upgrades are a deliberate action, not a side effect of
#                re-imaging. Run `brew upgrade` separately when you want it.
brew bundle \
  --file="$BREWFILE" \
  --verbose

info "Brewfile installation complete."

# Report anything declared in the Brewfile that isn't installed.
# brew bundle check exits non-zero if any package is missing.
if ! brew bundle check --file="$BREWFILE" --no-upgrade &>/dev/null; then
  warn "Some Brewfile entries could not be installed. Run 'brew bundle check --file=Brewfile' to inspect."
else
  info "All Brewfile entries satisfied."
fi

info "Homebrew Bundle complete"
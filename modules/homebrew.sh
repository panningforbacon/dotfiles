#!usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib.sh"
 
trap 'err_trap' ERR


# ── Helpers ────────────────────────────────────────────────────────────────────

# brew_prefix — canonical Homebrew prefix for this architecture.
# Apple Silicon: /opt/homebrew
# Intel:         /usr/local
brew_prefix() {
  if [[ "$(uname -m)" == "arm64" ]]; then
    echo "/opt/homebrew"
  else
    echo "/usr/local"
  fi
}


# ensure_brew_on_path — adds Homebrew to PATH for the remainder of this
# session if it isn't already resolvable. The shell profile is handled by
# shell.sh; this just makes `brew` available for subsequent modules when
# install.sh runs the full chain.
ensure_brew_on_path() {
  if ! command_exists brew; then
    local prefix
    prefix="$(brew_prefix)"
    eval "$("$prefix/bin/brew" shellenv)"
  fi
}


# ── Main ────────────────────────────────────────────────────────────────────

section "Homebrew installation"
require_macos
require_cmd git

if command_exists brew; then
  info "Homebrew already installed at: $(brew --prefix)"
  info "Updating Homebrew..."
  brew update --quiet
  info "Homebrew updated ($(brew --version | head -1))"
else
  info "Homebrew not found. Installing..."
 
  # The official install script. Piping to bash is Homebrew's own documented
  # method — there is no supported alternative.
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || fail "Homebrew installation failed."
 
  ensure_brew_on_path
  info "Homebrew installed ($(brew --version | head -1))"
fi

ensure_brew_on_path

info "Homebrew installation complete"
#!/usr/bin/env bash

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
      || error "Could not find Homebrew at $prefix. Run modules/homebrew.sh first."
  fi
}

# zsh_path — absolute path to the Homebrew-managed zsh binary
zsh_path() {
  "$(brew --prefix)/bin/zsh"
}

# -----------------------------------------------------------------------------
# zsh install guard
# -----------------------------------------------------------------------------

section "Shell: zsh"
require_macos
ensure_brew_on_path
require_cmd brew

if ! command_exists zsh; then
  error "zsh not found. Ensure 'brew \"zsh\"' is in your Brewfile and brew_bundle.sh has been run."
fi

ZSH_BIN="$(brew --prefix)/bin/zsh"
[[ -x "$ZSH_BIN" ]] || error "Homebrew zsh not executable at: $ZSH_BIN"

dim "Homebrew zsh: $ZSH_BIN ($(zsh --version))"

# -----------------------------------------------------------------------------
# Register Homebrew zsh in /etc/shells
# macOS requires a shell to be listed in /etc/shells before chsh will accept it.
# -----------------------------------------------------------------------------

if grep -qF "$ZSH_BIN" /etc/shells; then
  dim "$ZSH_BIN already registered in /etc/shells"
else
  info "Registering $ZSH_BIN in /etc/shells (requires sudo)..."
  echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
  info "Registered: $ZSH_BIN -> /etc/shells"
fi

# -----------------------------------------------------------------------------
# Set default shell
# chsh is a no-op if the shell is already set correctly, but it still prompts
# for a password. We skip the call entirely when unnecessary.
# -----------------------------------------------------------------------------

CURRENT_SHELL="$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')"

if [[ "$CURRENT_SHELL" == "$ZSH_BIN" ]]; then
  dim "Default shell already set to: $ZSH_BIN"
else
  info "Changing default shell to $ZSH_BIN (requires sudo)..."
  sudo chsh -s "$ZSH_BIN" "$USER" \
    || error "chsh failed. Run manually: sudo chsh -s $ZSH_BIN $USER"
  info "Default shell set to: $ZSH_BIN"
fi


# -----------------------------------------------------------------------------
# starship
# -----------------------------------------------------------------------------

section "Shell: starship"

if ! command_exists starship; then
  error "starship not found. Ensure 'brew \"starship\"' is in your Brewfile and brew_bundle.sh has been run."
fi

dim "starship: $(starship --version | head -1)"

# starship is initialized in the zshrc dotfile (symlinked by symlinks.sh).
# We don't write to ~/.zshrc here — that's symlinks.sh's job.
# Just confirm the config file will be in the right place once symlinks run.
STARSHIP_CONFIG_SRC="$DOTFILES_DIR/dotfiles/starship.toml"
STARSHIP_CONFIG_DST="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"

if [[ -f "$STARSHIP_CONFIG_SRC" ]]; then
  dim "starship config source: $STARSHIP_CONFIG_SRC"
  dim "starship config target: $STARSHIP_CONFIG_DST (will be linked by symlinks.sh)"
else
  warn "starship config not found at $STARSHIP_CONFIG_SRC — create it before running symlinks.sh."
fi

# -----------------------------------------------------------------------------
# zsh plugins
# Zsh-autosuggestions and zsh-syntax-highlighting are installed via Homebrew.
# Their source paths are referenced in the zshrc dotfile.
# Verify they exist so the zshrc doesn't silently fail to load them.
# -----------------------------------------------------------------------------

section "Shell: zsh plugins"

PLUGIN_BASE="$(brew --prefix)/share"
PLUGINS=(
  "zsh-autosuggestions/zsh-autosuggestions.zsh"
  "zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
)

all_plugins_ok=true
for plugin in "${PLUGINS[@]}"; do
  plugin_path="$PLUGIN_BASE/$plugin"
  if [[ -f "$plugin_path" ]]; then
    dim "Found: $plugin_path"
  else
    warn "Plugin not found: $plugin_path"
    warn "Ensure '$(dirname "$plugin" | tr '/' '-')' is in your Brewfile."
    all_plugins_ok=false
  fi
done

if $all_plugins_ok; then
  info "All zsh plugins present."
fi


info "Shell setup complete"
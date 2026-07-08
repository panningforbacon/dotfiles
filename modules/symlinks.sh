#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib.sh"

trap 'err_trap' ERR


# ── Helpers ────────────────────────────────────────────────────────────────────

# backup_file <path>
# Copies <path> to <path>.backup.<timestamp> before we clobber it.
# No-op if <path> doesn't exist.
backup_file() {
  local target="$1"
  if [[ -e "$target" ]]; then
    local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    cp -R "$target" "$backup"
    dim "Backed up: $target -> $backup"
  fi
}

# safe_symlink <source> <destination>
# Links <source> (repo file) to <destination> (live location).
# - Skips if the symlink already points to the correct source.
# - Backs up and replaces anything else at <destination>.
# - Creates parent directories as needed.
safe_symlink() {
  local src="$1"
  local dst="$2"

  require_file "$src"

  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    dim "Already linked: $dst"
    return 0
  fi

  backup_file "$dst"
  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
  success "Linked: $dst -> $src"
}

# # inject_and_link <template> <destination>
# # For templated dotfiles (e.g. gitconfig): runs inject_template to produce a
# # rendered file in $DOTFILES_DIR/generated/, then symlinks that to <destination>.
# # The generated/ directory is gitignored — it holds rendered secrets.
# inject_and_link() {
#   local template="$1"
#   local dst="$2"
#   local generated="$DOTFILES_DIR/generated/$(basename "$template" .template)"

#   mkdir -p "$DOTFILES_DIR/generated"

#   inject_template "$template" "$generated"
#   safe_symlink "$generated" "$dst"
# }

# -----------------------------------------------------------------------------
# Symlink map
# Format: safe_symlink <repo source> <live destination>
#
# To add a dotfile:
#   1. Add the file under dotfiles/ in the repo
#   2. Add a safe_symlink call below
# -----------------------------------------------------------------------------

section "Symlinks"


# ── zsh ────────────────────────────────────────────────────────────────────

safe_symlink \
  "$DOTFILES_DIR/dotfiles/zsh/.zshrc" \
  "$HOME/.zshrc"

safe_symlink \
  "$DOTFILES_DIR/dotfiles/zsh/zsh_plugins.txt" \
  "$HOME/zsh_plugins.txt"


# ── starship ────────────────────────────────────────────────────────────────────

safe_symlink \
  "$DOTFILES_DIR/dotfiles/starship/starship.toml" \
  "$HOME/.config/starship.toml"


# # ── git ────────────────────────────────────────────────────────────────────

# # gitconfig contains personal details (name, email) — use the template.
# # Requires GIT_NAME and GIT_EMAIL to be set (via .env.local or get_secret).
# if [[ -z "${GIT_NAME:-}" || -z "${GIT_EMAIL:-}" ]]; then
#   info "GIT_NAME and/or GIT_EMAIL not set in environment."
#   info "Attempting to retrieve from secrets backend..."
#   export GIT_NAME
#   export GIT_EMAIL
#   GIT_NAME="$(get_secret "git" "name")"
#   GIT_EMAIL="$(get_secret "git" "email")"
# fi

# inject_and_link \
#   "$DOTFILES_DIR/dotfiles/gitconfig.template" \
#   "$HOME/.gitconfig"

# safe_symlink \
#   "$DOTFILES_DIR/dotfiles/gitignore_global" \
#   "$HOME/.gitignore_global"


# ── vscode ────────────────────────────────────────────────────────────────────

safe_symlink \
  "$DOTFILES_DIR/dotfiles/vscode/settings.json" \
  "$HOME/Library/Application Support/Code/User/settings.json"

safe_symlink \
  "$DOTFILES_DIR/dotfiles/vscode/keybindings.json" \
  "$HOME/Library/Application Support/Code/User/keybindings.json"


# ── ssh ────────────────────────────────────────────────────────────────────

# ssh/config contains no secrets — just host aliases and options.
# Keys themselves are never stored in the repo.
safe_symlink \
  "$DOTFILES_DIR/dotfiles/ssh/config" \
  "$HOME/.ssh/config"

# Ensure correct permissions on .ssh — SSH refuses to run otherwise.
chmod 700 "$HOME/.ssh" 2>/dev/null || true
chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
dim "SSH directory permissions verified."


# ── curl ────────────────────────────────────────────────────────────────────

safe_symlink \
  "$DOTFILES_DIR/dotfiles/curlrc" \
  "$HOME/.curlrc"


# ── wget ────────────────────────────────────────────────────────────────────

safe_symlink \
  "$DOTFILES_DIR/dotfiles/wgetrc" \
  "$HOME/.wgetrc"


# ── hushlogin ────────────────────────────────────────────────────────────────────
# an empty file that suppresses the "Last login" message in new terminal tabs.

safe_symlink \
  "$DOTFILES_DIR/dotfiles/hushlogin" \
  "$HOME/.hushlogin"


info "Symlinks complete"
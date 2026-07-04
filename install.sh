#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DOTFILES_DIR/scripts/lib.sh"

trap 'err_trap' ERR


# ── Module registry ────────────────────────────────────────────────────────────────────
# Order is the dependency order; do not reorder casually. Exclude extension. 

ALL_MODULES=(
  xcode.sh
  homebrew.sh
  brew_bundle.sh
)


usage() {
  printf "Usage: %s [module...]\n\n" "$(basename "$0")"
  printf "With no arguments, runs all modules in order:\n"
  for m in "${ALL_MODULES[@]}"; do
    printf "  %s\n" "$m"
  done
  printf "\nPass one or more module names to run only those (in the order given).\n"
}

run_module() {
  local name="$1"
  local script="$DOTFILES_DIR/modules/${name}"
 
  if [[ ! -f "$script" ]]; then
    error "Module not found: $script"
  fi
 
  info "Starting module: $name"
  bash "$script"
  info "Module complete: $name"
}


# ── Main ────────────────────────────────────────────────────────────────────

main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
  fi
 
  require_macos
 
  local -a modules_to_run
 
  if [[ $# -eq 0 ]]; then
    modules_to_run=("${ALL_MODULES[@]}")
    info "Running all modules."
  else
    modules_to_run=("$@")
    info "Running modules: $*"
  fi
 
  for module in "${modules_to_run[@]}"; do
    run_module "$module"
  done
 
  info "All done."
}
 
main "$@"

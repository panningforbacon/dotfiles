#!/bin/zsh -f
# modules/defaults.zsh: placeholder so bin/provision has a stage to run and main
# stays runnable. Sprint 1 issue 7 replaces the body.
# Sourced by bin/provision; not executed on its own.

mod_defaults_run() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  log_start defaults 0
  log_finish
}
#!/bin/zsh -f
# modules/preflight.zsh: placeholder so bin/provision has a stage to run and main
# stays runnable. Sprint 1 issue 6 replaces the body.
# Sourced by bin/provision; not executed on its own.

mod_preflight_run() {
  emulate -L zsh; setopt NO_UNSET PIPE_FAIL
  log_start preflight 0
  log_finish
}
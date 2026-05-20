1. install Xcode Command Line Tools
2. Set up SSH keypair for GitHub



Here's a tight reference brief you can drop into any new chat:

---

**Bash Installer Module — Design Brief**

**Structure**
Functions defined at the top, linear control flow at the bottom under a `# ── main ──` banner. No logic in functions that belongs in control flow, and no control flow logic buried in functions.

**Function design**
- State detectors are pure: no output, no side effects, return 0/1 only. Named `_is_<thing>_<state>`.
- Action functions (`_install_*`, `_uninstall_*`) own logging and side effects for their specific operation.
- No single-use wrapper functions — if something is called once, inline it.

**Control flow pattern**
Set an `action` variable during the detection phase, then execute it in a `case` block. Default `action` to the safe forward path before any branching.

```bash
action="install"

if _is_foo_installed; then
  if _is_foo_working; then
    # prompt user, set action
  else
    # log outcome + action plan, set action="reinstall"
  fi
else
  # log not found, action stays "install"
fi

case "$action" in
  skip)     ... ; exit 0 ;;
  cancel)   ... ; exit 1 ;;
  reinstall) _uninstall_foo; _install_foo ;;
  install)   _install_foo ;;
esac
```

**Verification pattern**
Inline at the end of main using the state detectors. Use `die` on failure.

```bash
if _is_foo_installed && _is_foo_working; then
  log_success "..."
else
  ! _is_foo_installed && log_error "..."
  ! _is_foo_working   && log_error "..."
  die "Verification failed. Aborting."
fi
```

**Commenting style**
Section banners with `# ── section name ───...` (Unicode em-dash + trailing dashes to ~77 chars). Inline comments only where behavior isn't self-evident. No block comments above functions that merely restate the function name.

```bash
# ── state detectors ───────────────────────────────────────────────────────────

# ── install / uninstall ───────────────────────────────────────────────────────

# ── main ──────────────────────────────────────────────────────────────────────
```

Within main, single-line inline comments mark the three phases:
```bash
# Determine action.
# Execute action.
# Verify outcome.
```

**Logging conventions**
Source `logging.sh` which provides: `log_debug`, `log_info`, `log_warn`, `log_error`, `log_success`, `log_skip`, `die`.

| Situation | Function |
|---|---|
| Neutral progress | `log_info` |
| Something confirmed good | `log_success` |
| Non-fatal concern / destructive action about to happen | `log_warn` |
| Something failed | `log_error` |
| Skipping a step intentionally | `log_skip` |
| Unrecoverable — log + exit | `die` |

Message style: sentence case, no trailing period, concrete over vague. State *what* happened or is about to happen, not commentary on it.

```bash
# Good
log_warn "Removing Xcode CLT at ${path}..."
log_success "clang: $(command -v clang) — $(clang --version 2>&1 | head -1)"
die "Verification failed. Aborting."

# Bad
log_info "Please note that we will now attempt to begin the installation process."
log_success "Great, everything looks good!"
```

---

Paste that plus the finished `xcode.sh` as a concrete example and any new chat will have enough context to stay consistent.
# ADR-0002: Implementation language: zsh

| | |
| --- | --- |
| **Status** | Accepted — PO override of the tech lead's recommendation (bash 3.2) |
| **Date** | 2026-09-28 |
| **Deciders** | PO |
| **Related** | DEC-10R, DEC-12 (withdrawn), DEC-18, DEC-19; FR-1.2; CR-7 |

## Context

FR-1.2 limits the bootstrap to tools bundled with macOS, because git, Homebrew and the Xcode Command Line Tools are not yet present. On macOS 26 and 27 the bundled shells are:

- `/bin/bash` **3.2.57** (2007). Apple has not shipped a newer bash because later versions are GPLv3. It lacks associative arrays and `mapfile`.
- `/bin/zsh` **5.9**, the default interactive shell.

`/usr/bin/python3` and `/usr/bin/git` are stubs that trigger the Command Line Tools installer, so neither is usable at bootstrap.

The v1.3 DoD required every script to pass ShellCheck. ShellCheck supports sh, bash, dash and ksh, not zsh.

## Decision

All code targets **`/bin/zsh` 5.9**.

- **Startup-file isolation (DEC-18).** Every script's shebang is `#!/bin/zsh -f`. `-f` stops zsh from reading the user's startup files (a non-interactive zsh still reads `~/.zshenv`), so the dotfiles this project manages cannot change the provisioner's behavior. Every function starts with `emulate -L zsh`, which resets options to zsh defaults for that function only.
- **Strict mode (DEC-19).** Scripts enable options that fail fast on errors and unset variables. Candidates: `ERR_EXIT`, `NO_UNSET`, `PIPE_FAIL`. The first story that writes a script confirms the exact set against the zsh 5.9 manual and records it here.
- **Quality gate (CR-7).** ShellCheck is removed from the DoD. Replacement: every script passes `zsh -n`, and the fixture test suite passes.

## Rejected alternatives

- **bash 3.2 everywhere** (tech lead's recommendation). Bundled, ShellCheck-able, and the choice of Homebrew's own installer. Overruled by the PO: zsh is the macOS default shell, and the dotfiles are zsh too, so the project uses one dialect throughout.
- **bash 3.2 bootstrap that installs bash 5 and re-runs itself.** Preflight must run before any change (FR-2), so it would still be bash 3.2: two dialects, and Homebrew installed before its own module.
- **Python.** Not usable until the Command Line Tools are installed.

## Consequences

- **Gain:** associative arrays, rich parameter expansion, and one language across scripts and dotfiles.
- **Loss:** no static analysis beyond syntax. `zsh -n` catches parse errors only, so more weight falls on fixture tests and review.
- **Test tooling** must drive zsh (ADR-0004, spike S-6).
- **Portfolio:** zsh scripting is less common than bash; the README should state why it was chosen.
- **Pitfalls to guard in review:** arrays are 1-indexed; unquoted expansions do not word-split by default; options leak between functions unless `emulate -L zsh` is used.

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | Accepted during chartering (PO override). |

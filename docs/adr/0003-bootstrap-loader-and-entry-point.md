# ADR-0003: Bootstrap loader and entry point

| | |
| --- | --- |
| **Status** | Accepted — Command Line Tools install method confirmed by spike S-2 |
| **Date** | 2026-09-28 |
| **Deciders** | Tech lead (mechanism), PO (re-run semantics, clone-based bootstrap) |
| **Related** | DEC-11, DEC-13, DEC-31; FR-1.1–FR-1.3, FR-2, FR-8.2; CR-6, CR-15 |

## Context

- On a fresh Mac there is no git. `/usr/bin/git` is a stub that triggers the Xcode Command Line Tools installer.
- The permanent copy must be a real git working copy, because edits to linked dotfiles must show up in `git status` (FR-8.2).
- Re-running the pasted command is the normal way to apply changes (FR-1.3). If it always fetched remote `main`, local uncommitted edits would be silently ignored.
- `curl … | zsh` feeds the script through stdin, the channel prompts read from. That breaks the admin password prompt (FR-2.3) and the input prompt (FR-3.2).
- The PO accepted installing the Command Line Tools before preflight, to remove a second code path (CR-15).

## Decision

**The pasted command:**

```sh
/bin/zsh -f -c "$(curl -fsSL https://raw.githubusercontent.com/panningforbacon/dotfiles/main/bootstrap.zsh)"
```

The command substitution downloads the script first, so stdin stays attached to the terminal. `-f` skips the user's startup files (ADR-0002).

**`bootstrap.zsh` is a loader, not the provisioner:**

1. If `$DOTFILES_DIR/bin/provision` exists (`DOTFILES_DIR` defaults to `~/.dotfiles`), execute it with the given arguments, **as it stands**. Never pull (CR-6).
2. Otherwise:
   1. If the arguments include `--check`, print one `DIFF` line for the missing checkout and exit 0. Check mode makes no changes and has no manual stops (FR-16.1).
   2. If `/Library/Developer/CommandLineTools/usr/bin/git` is not executable, start the installer with `xcode-select --install`, print an `ACTION` line, and wait until that file is executable. The `ACTION` line says how to recover from a dismissed dialog: press Ctrl-C and paste the command again. `/usr/bin/git` is never run as a test, because the stub opens the dialog itself. This opens Apple's dialog: one manual stop. Spike S-2 chose this method over the headless one Homebrew's installer uses, from source and documentation; it first runs for real at the release wipe.
   3. `git clone` the repository into `$DOTFILES_DIR`. A directory that already holds other files is a `FAIL`; the loader never deletes it.
   4. Execute the new checkout's `bin/provision` with the given arguments.

The loader contains its own minimal copy of the §8.5 line format, because `lib/log.zsh` does not exist on disk until the clone succeeds.

**`bin/provision`** is the real entry point, used directly on a provisioned machine. Its options are documented in `docs/architecture.md` §3.

## Rejected alternatives

- **`curl … | zsh`.** Breaks prompts (see Context).
- **Tarball download, with the git checkout created later in the run** (charter v0.1). Kept FR-2's "no change before preflight" intact, but added a second code path exercised only at the release wipe, plus a tarball-to-checkout conversion. Rejected by the PO (CR-15).
- **Loader always pulls before running.** Ignores local edits and silently changes the code under the user (CR-6).

## Consequences

- There is one code path to the program, and it runs on every development run.
- On an unsupported Mac, the Command Line Tools may be installed before preflight rejects the machine. Accepted as harmless (CR-15).
- The fresh path (install, clone) is exercised in development by pointing `DOTFILES_DIR` at an empty temporary directory. The install step itself only runs for real at the release wipe, because the Command Line Tools are already present on the development Mac.
- Arguments pass through: `… bootstrap.zsh)" bootstrap --check`. With `zsh -c`, the first word after the command string becomes `$0`, hence the placeholder `bootstrap`.
- Pulling updates is always an explicit user action.

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | Accepted during chartering (tarball path). |
| 0.2 | 2026-09-28 | Replaced the tarball path with install-then-clone (CR-15). |
| 0.3 | 2026-10-03 | Step 2: completion check and cancel recovery from spike S-2; check mode without a checkout reports `DIFF`; occupied directory is a `FAIL` (issue #8). |
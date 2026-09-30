# ADR-0005: Homebrew integration via Brewfile

| | |
| --- | --- |
| **Status** | Accepted — PO override of the tech lead's recommendation (custom manifest, per-item install) |
| **Date** | 2026-09-28 |
| **Deciders** | PO |
| **Related** | DEC-16R, DEC-20R, DEC-21R, DEC-28, Q16; FR-6, FR-12, FR-13, FR-15.4; CR-8, CR-10, CR-11, CR-17 |

## Context

The PO reviews and edits the package list often and prefers Homebrew's standard `Brewfile` format. According to Homebrew's documentation:

- `brew bundle` upgrades all software by default. `--no-upgrade` (or `HOMEBREW_BUNDLE_NO_UPGRADE=1`) only skips `brew upgrade`; `brew install` may still upgrade dependencies.
- `brew bundle check` reports whether an install would do anything.
- `brew bundle upgrade` is shorthand for `brew bundle install --upgrade`.
- `brew bundle` also understands entry types outside this project's scope, including `mas` (Mac App Store) and `vscode` (VS Code extensions).

## Decision

- **Manifest:** a `Brewfile` at the repo root. Post-run setup notes are comments next to their entries. A header comment holds the manual reminders not tied to a package, including signing in to iCloud (CR-17). The run ends with one `NOTE` line pointing to the file (CR-8).
- **Behavior:** Homebrew's defaults, **upgrades included** (Q16, CR-11).
- **Logging:** the `brew` module wraps Homebrew in the converge contract with the whole Brewfile as **one item** (DEC-20R, CR-10):
  - check: `brew bundle check`;
  - apply: `brew bundle`, output passed through unmodified;
  - verify: `brew bundle check` again.
- **Homebrew itself** (FR-6.3): installed by the official installer with `NONINTERACTIVE=1` so it does not add its own prompt. Admin rights come from the live sudo ticket (ADR-0008). `.zprofile` evaluates `brew shellenv` so `brew` is on `PATH` in every login shell.
- **Scope rule (DEC-21R):** a comment at the top of the Brewfile states that `mas` and `vscode` entries are out of scope (PRD §5.2, FR-8.4). Nothing enforces it.
- **Color (DEC-28):** when our color is off, the module exports `HOMEBREW_NO_COLOR=1`.

## Rejected alternatives

- **Custom line-based manifest with per-item `brew install`** (tech lead's recommendation). Kept the §8.5 per-item log lines and a printed checklist. Overruled: the PO prefers the standard format and native output.
- **`brew bundle --no-upgrade`.** Kept FR-12.1. Overruled (Q16).
- **JSON or YAML manifest.** Nothing bundled with macOS parses them cleanly from zsh.

## Consequences

- Every run may upgrade packages. M3 is redefined as "no changes other than upstream releases" (CR-11).
- The Brewfile item almost always reports `CHANGED` when upstream has new releases. That is expected, not a convergence failure.
- Per-package progress is Homebrew's own format, not §8.5.
- `FR-13.2` (show only still-applicable checklist items) is gone.
- Adding a package is one Brewfile line (NFR-4).

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | Accepted during chartering (PO overrides). |
| 0.2 | 2026-09-28 | iCloud reminder moved into the Brewfile header (CR-17). |

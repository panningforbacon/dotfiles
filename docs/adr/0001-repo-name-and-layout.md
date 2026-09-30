# ADR-0001: Repository name and layout

| | |
| --- | --- |
| **Status** | Accepted |
| **Date** | 2026-09-28 |
| **Deciders** | PO (name, location), tech lead (layout) |
| **Related** | DEC-14, DEC-15; FR-8.2, NFR-4, NFR-6 |

## Context

The repository is public and doubles as a portfolio piece (NFR-6). Its name appears in the bootstrap URL and the README. Its location on disk is the source path of every linked dotfile (FR-8.2), so moving it later breaks every link. Adding a package, setting or runtime must mean editing one data file (NFR-4).

## Decision

- **Name:** `panningforbacon/dotfiles`. If an older repository named `dotfiles` exists on the account, rename or archive it first. Do not ship a repo named `dotfiles2`.
- **Location:** the permanent checkout lives at `~/.dotfiles`. Scripts read it from `$DOTFILES_DIR`, which defaults to that path. The override exists for testing (ADR-0003, ADR-0004).
- **Layout:** three layers, kept in separate top-level directories:
  - *data*: `Brewfile`, `macos/`, `home/`, `templates/`, `.env`;
  - *policy*: `modules/`, one file per run stage;
  - *mechanism*: `lib/`, shared helpers that know nothing about managed items.

  `home/` mirrors `$HOME`: a file at `home/.config/starship.toml` is linked to `~/.config/starship.toml`. The full tree is in `docs/architecture.md` §2.

## Rejected alternatives

- **A descriptive name such as `mac-provisioning`.** Clearer about scope, but `dotfiles` is the name readers look for on a GitHub profile.
- **A visible checkout such as `~/Developer/dotfiles`.** Equally workable. Rejected only because a hidden `~/.dotfiles` is the recognized convention and keeps the home folder uncluttered.
- **Flat layout (all scripts at the root).** Mixing data with code breaks NFR-4's "edit one data file, no logic" promise in practice: readers cannot tell which files are safe to edit.

## Consequences

- The bootstrap URL is fixed: `https://raw.githubusercontent.com/panningforbacon/dotfiles/main/bootstrap.zsh`.
- Renaming the repo or moving the checkout is a breaking change requiring a new ADR.
- A reader can tell data from code by directory alone.

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | Accepted during chartering. |

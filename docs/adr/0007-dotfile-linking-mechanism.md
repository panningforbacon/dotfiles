# ADR-0007: Dotfile linking mechanism

| | |
| --- | --- |
| **Status** | Accepted |
| **Date** | 2026-09-28 |
| **Deciders** | Tech lead (proposal), PO (acceptance) |
| **Related** | DEC-35; FR-8.2, FR-8.3, FR-8.6, FR-9.4, FR-14, §8.3, §8.5 |

## Context

- Config files are **linked, not copied**, so edits show up in `git status` (FR-8.2).
- If a regular file already exists at a link target, it is backed up with a timestamped name, never deleted, and a `WARN` line names both paths (FR-8.3).
- The git config is "generated from template + `.env`" (§8.3), but its shared settings should still be version-controlled.
- Every managed file needs its own §8.5 lines (converge contract).

## Decision

**Own zsh code, one symlink per file, driven by the `home/` directory tree.**

- Every regular file under `home/` is linked to the same relative path under `$HOME`. There is no mapping file: adding a dotfile means adding it under `home/` (NFR-4).
- Links are per **file**, never per directory, so tools that write extra files into their config directories do not write into the repo.
- Per file, the converge contract applies:
  - *check:* the target is a symlink pointing at the repo file;
  - *apply:* create parent directories; if a regular file or a wrong link exists, rename it to `<name>.bak-<YYYYMMDD-HHMMSS>` and log `WARN`; create the symlink;
  - *verify:* read the link back.
- **Git config split.** `home/.config/git/config` (linked, shared) holds everything that is the same on every machine, including SSH signing settings, plus an `[include]` of `~/.config/git/identity`. That identity file is **generated** from `templates/git-identity.tmpl` and `.env` values, and is never committed.

## Rejected alternatives

- **GNU Stow.** Refuses to link when a regular file is in the way, instead of backing it up (conflicts with FR-8.3), and prints its own output format.
- **chezmoi.** Manages copies rendered from a source state by default, which conflicts with FR-8.2's linked-not-copied rule, and adds a tool that owns its own directory conventions.
- **Dotbot or a YAML mapping file.** An extra dependency plus a second declarative file to keep in sync with the tree.
- **Linking whole directories** (for example `~/.config/nvim`). Anything the tool writes there, such as caches or lockfiles, lands in the repo.

## Consequences

- The dotfiles module is a small piece of our own code, fully covered by the §8.5 logging rules.
- Running `ls -la` in the home folder shows where each file comes from.
- Deleting a file from `home/` does not remove its link on the machine (FR-14.2: nothing undeclared is removed). A dangling link is left behind.

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | Proposed by the tech lead. |
| 1.0 | 2026-09-28 | Accepted by the PO at charter review. |

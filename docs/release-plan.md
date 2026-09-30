# Release plan — v1

| | |
| --- | --- |
| **Status** | Charter v1.0 — **accepted** by PO, 2026-09-29 |
| **Scope** | PRD v1.4 |
| **Planning depth** | Sprint 1 is broken down into issues (`docs/backlog/sprint-01.md`). Later sprints list a goal and candidate stories only. |

## How to read this plan

- A **sprint** is a small set of commits that leaves the repo runnable and produces a result the PO can see in the terminal. There is no calendar and no velocity tracking.
- An **epic** is a group of related stories. On GitHub, epics are labels (`epic/…`).
- A **spike** is a time-boxed, **read-only** investigation on the stakeholder's Mac. It produces a findings file in `docs/spikes/` and, where useful, captured command output in `tests/fixtures/`. Spikes never change system state, because the test machine is the stakeholder's only Mac (ADR-0004).
- **Prerequisite:** the Mac is on macOS 27 before sprint 1 starts (DEC-9).

## Epics

| Epic | Label | Requirements |
| --- | --- | --- |
| E1 Bootstrap and entry point | `epic/bootstrap` | FR-1, CR-6, CR-15 |
| E2 Preflight | `epic/preflight` | FR-2.1–FR-2.3, CR-1 |
| E3 Per-machine identity | `epic/inputs` | FR-3 |
| E4 Security baseline | `epic/security` | FR-5 |
| E5 Packages and apps | `epic/packages` | FR-6, FR-12, FR-13, CR-8, CR-10, CR-11, CR-17 |
| E6 Runtimes | `epic/runtimes` | FR-7, FR-12.2 |
| E7 Shell and dotfiles | `epic/dotfiles` | FR-8, CR-14 |
| E8 Git, SSH and GitHub | `epic/identity` | FR-9 |
| E9 macOS settings | `epic/settings` | FR-10, M4, CR-12, CR-16 |
| ~~E10 iCloud~~ | — | *Removed by CR-17* |
| E11 Run engine and logging | `epic/engine` | FR-14, FR-15, §8.5, CR-5, CR-9, CR-18 |
| E12 Release and docs | `epic/release` | DoD, M2, M3, NFR-3, NFR-6, CR-4, CR-7 |

## Sprints

### Sprint 1 — Walking skeleton

**Goal:** paste one command and watch a complete, correctly formatted run: preflight, one real managed item, a summary.

The walking skeleton is the thinnest end-to-end path through every layer: loader, entry point, library, one module, summary. Later sprints thicken it; none has to re-architect it.

Stories: see `docs/backlog/sprint-01.md` (10 issues: 1 chore for scaffolding, 1 chore for the quality gate, 6 build stories, 2 spikes).

| Spike | Question | Unblocks |
| --- | --- | --- |
| S-2 | How should the bootstrap install the Command Line Tools on macOS 27? Does a live sudo ticket prevent second prompts from Homebrew? | Sprint 1 bootstrap, sprint 4, ADR-0008 |
| S-6 | Which zsh test framework? | Sprint 1 quality gate |
| ~~S-1~~ | *Cancelled with DEC-3 (no VMs)* | — |
| ~~S-3~~ | *Cancelled by CR-12 and CR-13; FileVault detection moves into its story* | — |
| ~~S-4~~ | *Cancelled by PO; answered from Homebrew docs (ADR-0005)* | — |
| ~~S-5~~ | *Cancelled by CR-17* | — |

### Sprint 2 — Admin rights and the security baseline

**Goal:** one password prompt covers the whole run; the firewall is on; FileVault is reported.

Candidate stories:
- Admin password once, plus the sudo keep-alive (FR-2.3, ADR-0008).
- Firewall on (FR-5.2).
- FileVault warning (FR-5.1).

### Sprint 3 — Per-machine identity

**Goal:** a first run asks for per-machine values once; changing `COMPUTER_NAME` renames the Mac.

Candidate stories:
- `.env` loading and a single prompt for missing keys (FR-3.1, FR-3.2).
- Apply the computer name to all three name identifiers (FR-3.3, FR-3.4).

### Sprint 4 — Homebrew and the Brewfile

**Goal:** Homebrew is installed and on `PATH`, and the Brewfile converges.

Candidate stories:
- Install Homebrew non-interactively; `brew shellenv` in `.zprofile` (FR-6.3).
- Brewfile module as one logged item with passthrough (FR-6.1, FR-6.2, CR-10, CR-11).
- Brewfile content from §8.1: a setup-note comment on every entry that needs one, and a header with the scope rule and the iCloud reminder (CR-8, CR-17, DEC-21R).
- The `NOTE` pointer line in the summary (FR-13.1).

### Sprint 5 — Runtimes

**Goal:** `node` and `python3` resolve to the mise-managed defaults in a new shell, and uv never downloads its own Python.

Candidate stories:
- mise global config with Node 22, 24, 26 and Python 3.12, 3.14, plus defaults (FR-7.1–7.3).
- uv config (FR-7.4); `uv_venv_auto` (FR-7.5); `.python-version` discovery (FR-7.6).
- `--upgrade` for runtimes (CR-11).

### Sprint 6 — Dotfile linking, the shell, and config files

**Goal:** zsh starts with antidote, starship and zoxide active and no errors; every §8.3 file is linked; existing files are backed up with a `WARN`.

Candidate stories:
- Linking engine per ADR-0007 (FR-8.2, FR-8.3).
- `.zshrc` and `.zprofile` with their required blocks (FR-8.1, CR-14).
- Header-only files for antidote, starship, Ghostty and Neovim (FR-8.5, CR-14).

### Sprint 7 — Git, SSH and GitHub

**Goal:** a commit made on this Mac shows as **Verified** on GitHub.

Candidate stories:
- Per-machine SSH key with a passphrase stored in the Keychain (FR-9.1, FR-9.5).
- GitHub browser login; register the key for authentication and signing (FR-9.2, FR-9.3).
- Shared git config plus the generated identity file (FR-9.4, ADR-0007).

### Sprint 8 — Settings engine and the first areas

**Goal:** the settings manifest converges for Dock, Spaces and Finder, with one compact line per intent.

Candidate stories:
- Spike S-7: on macOS 27, find the working key for each remaining ⚠ Finder row in §8.4. Read-only.
- Parser and engine per ADR-0006; restart the Dock and Finder (FR-10.1, FR-10.3).
- Dock, Spaces and Finder entries, with effect verification recorded (FR-10.2, M4).

### Sprint 9 — Remaining settings

**Goal:** every remaining §8.4 row is verified effective, or explicitly dropped with PO approval.

Candidate stories:
- The remaining §8.4 areas, with M4 evidence.
- Logout notices in the summary (FR-10.3).

### Sprint 10 — Release

**Goal:** the DoD is met.

Candidate stories:
- README: purpose, design principles, the "update macOS first" instruction, bootstrap command, `--check`, `--upgrade`, expected stops, how to add a package or setting (DoD, CR-13).
- History audit for secrets and personal identifiers (NFR-3).
- **The release wipe** (CR-4): back up, wipe, provision from the pasted command, measure M2, and run twice more for M3.

## Risk-driven ordering

- The two remaining spikes come in sprint 1, because the bootstrap and the test gate depend on them.
- Settings come late because Apple changes defaults keys between releases. Settings verification then happens on the final macOS version before release.
- The release wipe comes last because it is the only fresh-install evidence and it costs the stakeholder a machine rebuild.

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | First draft. Sprint 0 folded into sprint 1. |
| 1.0 | 2026-09-28 | No content changes; version aligned with the charter. |
| 0.2 | 2026-09-28 | Applied CR-12 to CR-18: 10 sprints; spikes S-3 and S-5 cancelled; E10 removed; E4 renamed. |

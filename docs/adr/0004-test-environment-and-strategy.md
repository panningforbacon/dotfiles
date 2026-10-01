# ADR-0004: Test environment and strategy

| | |
| --- | --- |
| **Status** | Accepted — test framework chosen by spike S-6 |
| **Date** | 2026-09-28 |
| **Deciders** | PO (environment), tech lead (strategy) |
| **Related** | DEC-3, DEC-4, DEC-7, DEC-8, DEC-9, DEC-18, DEC-31; D3, M2, M3, M4; CR-2, CR-4, CR-5, CR-7, CR-15; spike S-6 |

## Context

- The stakeholder owns one Mac, a daily-use MacBook Pro, upgraded to macOS 27 before sprint 1 (DEC-9). It cannot be wiped during development.
- The PO declined virtual machines (DEC-3) and accepted the resulting verification gaps.
- Several branches can never fire on that machine during development:
  - first-time installs of software already present, including the Command Line Tools;
  - the Intel branch of preflight.

  The scope cuts in CR-12, CR-13 and CR-15 removed the other unreachable branches (the tarball bootstrap, the major-upgrade bail and the Full Disk Access check).
- macOS 26 is never exercised (tolerated tier, CR-1).

## Decision

Four layers of evidence, from cheapest to most expensive:

1. **Syntax gate.** `scripts/check` runs `zsh -n` on every script (CR-7).
2. **Fixture tests.** Every parser of system-command output (`sw_vers`, `fdesetup`, `defaults read`, …) takes its input as text, so tests feed it saved output from `tests/fixtures/`. Fixtures come from spikes run on the real Mac, plus hand-written variants for branches that cannot occur there. The log formatter is tested the same way. `scripts/check` runs this suite.
3. **Live runs on the daily Mac**, in a fixed order for every story:
   1. `bin/provision --check` (no changes; CR-5);
   2. `bin/provision` (converge);
   3. `bin/provision` again, which must report zero changes other than upstream releases (M3).
4. **The release wipe** (CR-4). One wipe-and-provision of the Mac is the only fresh-run evidence: FR-1.1 acceptance and M2 are measured there.

**Test framework: ShellSpec 0.28.1** (spike S-6, `docs/spikes/S-6-test-framework.md`).

- **Runs in zsh.** Specs, the libraries under test and stub functions share one zsh process, so tests are written in the project's one dialect (ADR-0002), and stubs are plain zsh functions.
- **Always invoked as `--shell "/bin/zsh -f"`,** set in the repo's `.shellspec` options file. Without `-f`, ShellSpec's zsh reads `~/.zshenv`, so the dotfiles this project manages could change test results (DEC-18). The suite includes a test that fails if `-f` is missing.
- **Vendored and pinned** under `tests/vendor/shellspec/`, not installed with Homebrew. `scripts/check` then works straight after a clone, before the `brew` stage has run, and the version cannot drift.
- **Test files are not scripts.** Spec files (`*_spec.zsh`) are exempt from the `#!/bin/zsh -f` shebang rule and from the rule that output goes through `log`. Code under `lib/` that they exercise is not.

## Rejected alternatives

- **macOS VMs (Tart, UTM, Parallels).** They make "wipe" cheap and would cover macOS 26. Declined by the PO (DEC-3).
- **Live runs only, no fixture tests.** Leaves the unreachable branches above with no evidence at all.
- **GitHub-hosted macOS CI runners.** Not a fresh install (preinstalled tooling, passwordless sudo) and listed as "Later" in the PRD.
- **bats-core as the test framework.** The only candidate under active development (v1.14.0, July 2026), but tests are written in bash and reach zsh only through a subprocess per assertion. Every test body and every stub becomes zsh inside a bash string, and the two dialects fail silently in each other's syntax (S-6 recorded a passing test that only worked by accident). It stays the fallback if ShellSpec stops working on a future macOS.
- **ZUnit.** zsh-native, but unmaintained: last release January 2018, last commit June 2020. It also needs `revolver` on `PATH`.
- **zsh-test-runner (ztr).** zsh-native and small, but licensed CC BY-NC-SA 4.0 plus the Hippocratic License. That license cannot be vendored into this MIT repository, and it is a poor fit for a public portfolio repo (NFR-6).
- **A homegrown runner in `tests/`.** No dependency, but the test infrastructure itself would be untested code. It stays the second fallback.
- **ShellSpec installed with Homebrew.** Adds a package outside the PRD's package list (a change request), and makes the quality gate depend on the `brew` stage.

## Consequences

- Fresh-install bugs surface at the release wipe, on the stakeholder's only machine. Mitigations: the pre-wipe backup (CR-4), idempotency (FR-14.3), and exercising the clone path with a temporary `DOTFILES_DIR`.
- M4 evidence exists for macOS 27 only. The repo lists unverified settings explicitly (CR-2).
- Every story's acceptance includes the three-run live sequence.
- ShellSpec has not been released since January 2021. It depends only on POSIX `sh` and zsh 5.9, and the vendored copy is pinned, so the risk is limited to a future macOS changing either shell. Specs stay thin (fixtures and assertions; logic lives in `lib/`), so a move to the bats-core fallback is a rewrite of test files only.
- ShellSpec's DSL (`Describe`, `It`, `When`, `The`) is a small extra syntax. Everything outside its keywords is ordinary zsh.

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | Accepted during chartering; framework open. |
| 0.2 | 2026-09-28 | Updated unreachable branches after CR-12, CR-13 and CR-15. |
| 0.3 | 2026-09-30 | Recorded the pending test framework: ShellSpec 0.28.1, vendored, run under `zsh -f` (spike S-6). Filling a decision this ADR marked pending, per working agreements §6. |

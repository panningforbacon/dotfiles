# ADR-0004: Test environment and strategy

| | |
| --- | --- |
| **Status** | Accepted — test framework pending spike S-6 |
| **Date** | 2026-09-28 |
| **Deciders** | PO (environment), tech lead (strategy) |
| **Related** | DEC-3, DEC-4, DEC-7, DEC-8, DEC-9, DEC-31; D3, M2, M3, M4; CR-2, CR-4, CR-5, CR-7, CR-15 |

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

**Test framework:** chosen by spike S-6. Candidates include bats-core, which runs tests in bash and would drive zsh code through subprocesses, and zsh-native frameworks such as ZUnit. S-6 compares maintenance status, zsh support and install path, then this ADR records the choice.

## Rejected alternatives

- **macOS VMs (Tart, UTM, Parallels).** They make "wipe" cheap and would cover macOS 26. Declined by the PO (DEC-3).
- **Live runs only, no fixture tests.** Leaves the unreachable branches above with no evidence at all.
- **GitHub-hosted macOS CI runners.** Not a fresh install (preinstalled tooling, passwordless sudo) and listed as "Later" in the PRD.

## Consequences

- Fresh-install bugs surface at the release wipe, on the stakeholder's only machine. Mitigations: the pre-wipe backup (CR-4), idempotency (FR-14.3), and exercising the clone path with a temporary `DOTFILES_DIR`.
- M4 evidence exists for macOS 27 only. The repo lists unverified settings explicitly (CR-2).
- Every story's acceptance includes the three-run live sequence.

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | Accepted during chartering; framework open. |
| 0.2 | 2026-09-28 | Updated unreachable branches after CR-12, CR-13 and CR-15. |

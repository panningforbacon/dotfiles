# ADR-0009: Logging library structure

| | |
| --- | --- |
| **Status** | Accepted |
| **Date** | 2026-09-28 |
| **Deciders** | Tech lead (library), PO (API shape and vocabulary) |
| **Related** | DEC-27, DEC-28, DEC-29, DEC-30; FR-15, §8.5; CR-9, CR-10, CR-18 |

## Context

§8.5 fixes the line anatomy, a status vocabulary, per-module start and finish headers with counts, a compact form for settings, color rules, and stderr for `FAIL`. Every line must comply (FR-15.4). The only exception is Homebrew's own output (CR-10).

CR-18 reduced the vocabulary to `OK`, `CHANGED`, `DIFF`, `FAIL`, `WARN`, `ACTION` and `NOTE`, with exactly one line per managed item.

**Statuses are not log levels.** A log level (DEBUG, INFO, WARN, ERROR) measures severity, for filtering. A status records what happened to one managed item. "Installed" and "already installed" have the same severity but opposite outcomes, and §8.5's readability rule depends on telling them apart: a converged run is a quiet column of dim `OK`s.

## Decision

**One library, `lib/log.zsh`, is the only code allowed to print. It has three functions:**

```zsh
log_start <module> <item-count>        # ▶ header; sets the current module
log <STATUS> <subject> <message>       # every other line
log_finish                             # ■ header with this module's counts
```

- **Table-driven.** One associative array maps each status to its stream, color and counter (`docs/architecture.md` §7). `log` looks the status up. An unknown status prints a `FAIL` naming it, so a typo fails loudly on first use.
- **Callers write their own messages.** The converge helper supplies the standard phrasing for `OK`, `CHANGED`, `DIFF` and `FAIL`. Modules call `log` directly for `WARN`, `NOTE`, `ACTION` and module-specific `FAIL` lines. The `defaults` module formats its own dot-padded compact message.
- **Counts** live in one associative array keyed by module and counter. `log_finish` and the run summary read the same array, so they cannot disagree.
- **Timestamps** use zsh's `strftime` from `zsh/datetime`, which avoids spawning `date` for every line.
- **Color** is decided per stream: on only if that stream is a terminal and `NO_COLOR` is unset or empty. The same decision sets `HOMEBREW_NO_COLOR` (DEC-28).
- **Secrets** are never passed to `log` (FR-15.8).

## Rejected alternatives

- **One function per status** (`log_ok`, `log_warn`, …; charter v0.1). Same behavior, about 20–30 more lines. Rejected by the PO: more names to learn for no gain.
- **Log levels with free-text messages** (`info`, `warn`, `error`). Smallest, and familiar. Rejected because it cannot tell "changed" from "already correct", so it breaks §8.5 and the summary counts (M3).
- **Modules emit structured events that a separate formatter renders.** Overbuilt for a single-user terminal tool with no log files (FR-15.2).

## Consequences

- A new status is one table row plus one row in §8.5.
- The formatter is testable with fixtures: call `log`, compare against an expected line (ADR-0004).
- Long-running applies print nothing until they finish, because there is no `RUN` line. The longest one, Homebrew, streams its own output (CR-10).
- The bootstrap loader duplicates a minimal formatter, because this library is not on disk yet (ADR-0003).

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | Accepted during chartering (one function per status). |
| 0.2 | 2026-09-28 | Table-driven `log` function and reduced vocabulary (DEC-29, DEC-30, CR-18). |

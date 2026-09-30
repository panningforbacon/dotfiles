# ADR-0008: Admin privileges for the whole run

| | |
| --- | --- |
| **Status** | Accepted — no-second-prompt behavior confirmed by spike S-2 |
| **Date** | 2026-09-28 |
| **Deciders** | Tech lead |
| **Related** | DEC-26; FR-2.3, FR-14.3, FR-15.8, M2 |

## Context

FR-2.3 requires one admin password prompt, with privileges lasting for the whole run. A sudo ticket expires after a few minutes (5 by default unless sudoers overrides it), and a fresh run takes far longer. Homebrew's installer and some casks call `sudo` themselves. Homebrew refuses to run as root.

## Decision

**A sudo keep-alive.**

- Preflight runs `sudo -v` once: this is the single password prompt.
- A background loop refreshes the ticket non-interactively (`sudo -n -v`) about every 60 seconds. It stops when the main process exits, via an exit trap plus a liveness check on the parent process ID.
- The program runs as the user. Individual commands that need root call `sudo` and find a valid ticket.
- In `--check` mode no password is requested. Checks that need root report their item as unknown instead of prompting.

## Rejected alternatives

- **Temporary passwordless-sudo rule in `/etc/sudoers.d`.** If the run is interrupted, the rule survives and the machine keeps passwordless sudo: a security hole that also breaks FR-14.3.
- **Run the whole program as root.** Homebrew refuses, and every user-owned file written would need its ownership fixed.
- **Prompt again whenever the ticket expires.** Adds manual stops (M2) and breaks FR-2.3.

## Consequences

- Spike S-2 must confirm on macOS 27 that the Homebrew installer and casks see the live ticket and do not prompt. Tickets are tied to the terminal, and the loop runs on the same one.
- A crash that bypasses the exit trap leaves the loop running until its parent check notices, within about 60 seconds.
- The password is never read or stored by our code; `sudo` handles it (FR-15.8).

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | Accepted during chartering. |

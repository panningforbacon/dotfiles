# PRD v1.4 change requests

| | |
| --- | --- |
| **Applies to** | `docs/prd.md` v1.3 (approved 2026-09-27) |
| **Status** | All CRs approved by PO during chartering, except CR-3 (withdrawn). **All merged into PRD v1.4 on 2026-09-29.** This file is now a historical record. |
| **Merge rule** | The PO applies these to the PRD as v1.4 in one commit, then marks each CR `Merged`. |

Decision IDs (`DEC-n`) refer to the charter decision log in `docs/architecture.md` §11.

---

## CR-1 — Supported macOS versions, in two tiers

- **Sections:** §9 NFR-5, FR-2.2
- **Proposed text (NFR-5):** "Supported: Apple Silicon on macOS **Golden Gate (27)** — *verified tier* — and **Tahoe (26)** — *tolerated tier*. A version enters the verified tier only after M4 verification passes on it. On a tolerated version, preflight prints a `WARN` that the version is unverified, then continues."
- **Proposed text (FR-2.2):** "Verify the macOS version is in the verified or tolerated tier (NFR-5). Otherwise, exit with a message."
- **Reason:** macOS 27 was released 2026-09-14, before v1.3 sign-off. The stakeholder's only Mac will run 27, so 26 can never be verified (DEC-1, DEC-6).
- **Status:** Merged in PRD v1.4 · Approved

## CR-2 — Test environment is the stakeholder's single Mac

- **Sections:** §11 D3, §3 M4, §15 DoD
- **Proposed text (D3):** "Resolved: the stakeholder's single Mac, on the verified-tier macOS version. It is not wipeable during development. No virtual machines are used."
- **Proposed text (M4, "How measured"):** "Verification evidence per setting (§8.4), collected on the stakeholder's Mac on its installed version. Settings not verifiable there are listed as unverified in the repo."
- **Proposed text (DoD item 1):** "All MUST requirements pass their acceptance criteria on the stakeholder's Mac (see CR-4 for fresh-run criteria)."
- **Reason:** DEC-3. The stakeholder owns one Mac (DEC-4) and declined VMs.
- **Status:** Merged in PRD v1.4 · Approved

## CR-3 — Major-upgrade rule when several majors are offered

- **Section:** FR-2.4
- **Proposed text:** "If **any** offered major macOS version is newer than the current one **and** is in the verified tier (NFR-5), exit and instruct the user to upgrade and re-run. Otherwise, if any newer major is offered, print a warning and continue."
- **Reason:** v1.3 is ambiguous when `softwareupdate` offers more than one major (DEC-5).
- **Status:** **Withdrawn**: superseded by CR-13, which deletes FR-2.4.

## CR-4 — Fresh-run evidence comes from one planned wipe at release

- **Section:** §15 DoD
- **Proposed text (replace "Stakeholder has run a full fresh provision and accepted it"):** "Release acceptance is one planned wipe-and-provision of the stakeholder's Mac. Before the wipe, iCloud Drive is fully synced and one Time Machine backup exists. FR-1.1 acceptance and M2 are measured during this run."
- **Reason:** The development machine is never fresh, so fresh-install paths are otherwise never exercised (DEC-7). The pre-wipe backup is operational hygiene; the "Backups" non-goal stands.
- **Status:** Merged in PRD v1.4 · Approved

## CR-5 — Check mode moves into v1

- **Sections:** §16 Later; new FR-16
- **Proposed text (new FR-16, SHOULD):** "**FR-16.1 (SHOULD)** A documented check option runs every check and no apply step. It makes no changes and has no manual stops. Items that would change are reported with the `DIFF` status (§8.5, CR-9). The summary reports how many items would change."
- **Proposed text (§16):** delete "Dry-run / check mode that reports differences without changing anything."
- **Reason:** Every sprint runs on the stakeholder's only machine; a read-only preview reduces risk (DEC-8).
- **Status:** Merged in PRD v1.4 · Approved

## CR-6 — What a re-run executes

- **Section:** FR-1.3
- **Proposed text (append):** "When a local checkout already exists, the bootstrap command runs **that checkout as it stands**, including uncommitted edits, and never pulls from GitHub. The user pulls when they choose."
- **Reason:** Without this, re-running the pasted command would fetch remote `main` and silently ignore local edits, breaking the edit-and-re-run workflow in §2 (DEC-13).
- **Status:** Merged in PRD v1.4 · Approved

## CR-7 — Replace the ShellCheck gate

- **Section:** §15 DoD
- **Proposed text (replace the shellcheck item):** "Every script passes `zsh -n`, and the fixture test suite passes."
- **Reason:** The PO chose zsh as the implementation language (DEC-10R). ShellCheck does not support zsh. The replacement gate is weaker: `zsh -n` catches syntax errors only.
- **Status:** Merged in PRD v1.4 · Approved

## CR-8 — Post-run notes live in the Brewfile

- **Sections:** FR-13, FR-15.3, §8.5, §8.1
- **Proposed text (FR-13.1):** "At the end of a successful run, print one `NOTE` line directing the user to the per-package comments in the `Brewfile`."
- **Proposed text (FR-13.2):** delete.
- **Proposed text (FR-15.3 and §8.5 "The run ends with a summary"):** replace "then the post-run checklist" with "then the Brewfile pointer (FR-13.1)".
- **Proposed text (§8.1 "Post-run note" column):** "Recorded as comments in the `Brewfile`."
- **Reason:** PO override of DEC-16: the Brewfile is the package manifest (DEC-16R), and the stakeholder reviews it often.
- **Status:** Merged in PRD v1.4 · Approved

## CR-9 — Two new statuses: `DIFF` and `NOTE`

- **Section:** §8.5 status vocabulary
- **Proposed text (add rows):**

  | Event | STATUS | Color | Phrasing rule | Example message |
  | --- | --- | --- | --- | --- |
  | Check mode: item would change | `DIFF` | cyan | observed state, then `— would change` | `Screenshots folder: missing — would change` |
  | Neutral information | `NOTE` | none | plain statement | `Per-package setup notes: see comments in ~/.dotfiles/Brewfile` |

- **Proposed text (compact form, Result column):** add `would change` (check mode).
- **Reason:** CR-5 needs a non-mutating status; CR-8's pointer line is neither a warning nor a manual stop.
- **Status:** Merged in PRD v1.4 · Approved. Both statuses survive in CR-18's reduced vocabulary.

## CR-10 — Homebrew output passes through

- **Sections:** FR-15.4, §8.5
- **Proposed text (append to FR-15.4):** "Exception: output from Homebrew commands (the Homebrew installer and `brew bundle`) passes through unmodified between the `brew` module's start and finish headers. The module reports the Brewfile as a single item."
- **Reason:** PO override of DEC-20: use Homebrew's default behavior and logging (DEC-20R).
- **Status:** Merged in PRD v1.4 · Approved

## CR-11 — Homebrew upgrades on every run

- **Sections:** FR-12, §3 M3
- **Proposed text (FR-12.1):** delete.
- **Proposed text (FR-12.2):** "Homebrew items follow Homebrew Bundle's default behavior and are upgraded on every run. An explicit, documented upgrade option upgrades mise-managed runtimes: Node versions to the latest patch within each declared major, Python versions to the latest patch within each declared minor. Without that option, runtimes are only installed when missing."
- **Proposed text (M3 target):** "Second consecutive run makes 0 changes other than upstream releases, and has 0 manual stops."
- **Reason:** PO decision (Q16). `brew bundle` upgrades by default. Deleting FR-12.1 outright would also have left mise's no-upgrade default unspecified, so the rewritten FR-12.2 keeps it (DEC-34).
- **Status:** Merged in PRD v1.4 · Approved, including the FR-12.2 wording

## CR-12 — Drop the Safari settings and the Full Disk Access check

- **Sections:** FR-2.5, §8.4 (three Safari rows), §7, §12
- **Proposed text (FR-2.5):** delete.
- **Proposed text (§8.4):** delete the rows *Develop menu*, *Web Inspector* and *Don't auto-open downloads*.
- **Proposed text (§7):** delete the "No Full Disk Access" branch from the flowchart and the FDA stop from the stop estimate.
- **Proposed text (§12):** delete the risk "Granting FDA requires a terminal relaunch".
- **Reason:** The Safari rows were the only reason for Full Disk Access. That check cost a preflight branch, a guaranteed bail-out and re-run on every fresh run, and three rows already flagged ⚠. The Develop menu can be switched on by hand once (DEC-31).
- **Status:** Merged in PRD v1.4 · Approved

## CR-13 — Drop macOS update handling

- **Sections:** FR-2.4, FR-4, §5.1, §5.2, §7, §12, DoD (README)
- **Proposed text (FR-2.4, FR-4):** delete.
- **Proposed text (§5.1):** delete "Minor macOS updates."
- **Proposed text (§5.2, new row):** "macOS updates, minor or major | The README instructs the user to update macOS before running."
- **Proposed text (§7):** delete the "Major upgrade available" branch and the "Minor updates?" step, and the restart stop from the estimate.
- **Proposed text (§12):** delete the risk "Detecting whether a major upgrade is available is unreliable".
- **Proposed text (DoD, README bullet list):** add "the instruction to update macOS before running".
- **Reason:** Parsing `softwareupdate` output was the most fragile code in the project, and the major-upgrade branch could not be tested before macOS 28 ships (DEC-31). Supersedes CR-3.
- **Status:** Merged in PRD v1.4 · Approved

## CR-14 — Config templates contain only what the PRD requires

- **Sections:** FR-8.6, §8.3, DoD
- **Proposed text (FR-8.6):** "Each config file in §8.3 contains its **required block** only, preceded by a header comment naming the tool and linking to its official settings reference. A file with no required content ships as the header alone. *Acceptance:* each tool starts with its file with no errors or warnings."
- **Proposed text (§8.3 intro):** replace "ships as a **template** … commented out" with "ships with its required content only (FR-8.6)."
- **Proposed text (DoD):** "Every §8.3 file meets FR-8.6."
- **Reason:** The commented-defaults requirement was cheap in code but expensive in research: every value had to be checked against a tool's docs for a recorded version (DEC-31). A header-only file still gives the user an obvious place to add settings and keeps FR-8.5 meaningful.
- **Status:** Merged in PRD v1.4 · Approved

## CR-15 — The bootstrap installs the Command Line Tools and clones the repo

- **Sections:** FR-1.2, FR-2 introduction
- **Proposed text (FR-1.2):** "The bootstrap uses only tools bundled with macOS until it has installed the Xcode Command Line Tools. It then clones the repository with git into the checkout location. Installing the Command Line Tools opens Apple's installer dialog: one manual stop, first run only."
- **Proposed text (FR-2 introduction):** "The run stops before making any changes if a preflight check fails. Exception: the bootstrap may already have installed the Xcode Command Line Tools (FR-1.2)."
- **Reason:** Removes the tarball download path and the later tarball-to-checkout conversion. Only one code path remains, the one exercised on every development run (DEC-31). Installing the Command Line Tools on an unsupported Mac, before preflight rejects it, is harmless: Homebrew's installer would install them anyway.
- **Status:** Merged in PRD v1.4 · Approved

## CR-16 — Drop three settings suspected to be ineffective

- **Section:** §8.4
- **Proposed text:** delete the rows *Battery percentage*, *Password immediately after sleep/screensaver* and *Font smoothing on non-Apple displays*.
- **Reason:** These rows were the most likely to need custom mechanisms, the most expensive part of the settings engine (DEC-31). The remaining ⚠ rows (Finder) are suspected wrong key names, fixable by swapping the key.
- **Status:** Merged in PRD v1.4 · Approved

## CR-17 — iCloud becomes a reminder, not a stop

- **Sections:** FR-11, §5.1, §7, §12
- **Proposed text (FR-11):** delete, and add to FR-13.1: "The Brewfile's header comment includes the reminder to sign in to iCloud."
- **Proposed text (§5.1):** replace "iCloud sign-in checkpoint" with "iCloud sign-in reminder (FR-13.1)".
- **Proposed text (§7):** delete the iCloud stop.
- **Proposed text (§12):** delete the risk "Detecting iCloud sign-in state is unreliable".
- **Reason:** Removes a manual stop, a spike and an unreliable detection routine. A missing iCloud sign-in is obvious within minutes (DEC-31).
- **Status:** Merged in PRD v1.4 · Approved

## CR-18 — Reduced logging vocabulary

- **Sections:** §8.5, FR-15.5, FR-15.6
- **Proposed text (§8.5 status vocabulary):** the statuses are `▶` (module start), `OK`, `CHANGED`, `DIFF`, `FAIL`, `WARN`, `ACTION`, `NOTE`, and `■` (module finish). Delete `CHECK`, `RUN`, `DONE` and `VERIFY`.
- **Proposed text (§8.5 rules, "Line counts"):** "Every managed item emits exactly **one** line: `OK` if already correct, `CHANGED` if applied and the read-back confirms it, `DIFF` in check mode, or `FAIL`. `CHANGED` means the effect was read back and confirmed, never only that the command succeeded."
- **Proposed text (§8.5, phrasing for `CHANGED`):** "past tense, then `— verified`", for example `neovim: installed — verified`.
- **Proposed text (§8.5):** delete the rule "`DONE` and `VERIFY` are never merged".
- **Proposed text (FR-15.6):** unchanged. macOS settings keep the compact dot-padded form, which already has one line per setting.
- **Reason:** PO decision (DEC-30). Removes the four-line lifecycle and its branching in the converge helper. Verification still happens on every change; only its separate line goes.
- **Status:** Merged in PRD v1.4 · Approved

---

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | CR-1 to CR-11 drafted and approved during chartering. |
| 0.2 | 2026-09-28 | Added CR-12 to CR-18 (scope cuts and logging). CR-3 withdrawn. |
| 0.3 | 2026-09-28 | PO confirmed the CR-11 wording for FR-12.2. |
| 1.0 | 2026-09-29 | All CRs merged into PRD v1.4. |

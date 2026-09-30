# Sprint 1 backlog — Walking skeleton

| | |
| --- | --- |
| **Status** | Charter v1.0 — **accepted** by PO, 2026-09-29 |
| **Milestone** | `Sprint 1 — Walking skeleton` |
| **How to use this file** | Create each issue below by hand on GitHub (walkthrough in the next section). After that, GitHub is the source of truth for the issues; this file stays as the sprint's original plan. |

## Creating the sprint on GitHub, by hand

GitHub's layout changes from time to time; if a button isn't exactly where described, look for the same word nearby. Everything happens on the repo page, `github.com/panningforbacon/dotfiles`.

### Key terms

- **Issue.** One unit of work, with a number (`#7`), a title, a Markdown body, and a state (open or closed). Here, one issue is one story, spike or chore.
- **Label.** A colored tag used to filter issues. This repo uses two families:
  - `type/…` says what kind of work it is: `type/story` (a visible increment), `type/spike` (read-only investigation), `type/chore` (hygiene with no user-visible change).
  - `epic/…` says which epic the issue belongs to (see `docs/release-plan.md`).
- **Milestone.** A named group of issues with a progress bar. Here, one milestone is one sprint. The sprint is done when its milestone shows 100%.

### Step 1 — Create the three type labels (once, ever)

1. Open the **Issues** tab, then **Labels**.
2. GitHub creates default labels (`bug`, `enhancement`, …). Leave or delete them; this repo doesn't use them.
3. Click **New label** three times:

   | Name | Description | Color |
   | --- | --- | --- |
   | `type/story` | A visible increment of working software | any blue |
   | `type/spike` | Time-boxed, read-only investigation | any purple |
   | `type/chore` | Hygiene with no user-visible change | any gray |

**Epic labels** are created the moment an issue first needs one (DEC-33), from the label picker inside the issue: type a name that doesn't exist yet and GitHub offers to create it. Sprint 1 needs five: `epic/bootstrap`, `epic/preflight`, `epic/settings`, `epic/engine`, `epic/release`. Use one color for all epic labels, so they read as one family.

### Step 2 — Create the milestone (once per sprint)

1. **Issues** tab → **Milestones** → **New milestone**.
2. Title: `Sprint 1 — Walking skeleton`. Description: `Thinnest end-to-end run, plus the two blocking spikes.` Leave the due date empty: sprints have no calendar.

### Step 3 — Create each issue (10 times)

For each issue in the backlog below:

1. **Issues** tab → **New issue**.
2. **Title:** copy the heading text after `Issue n:`.
3. **Body:** copy everything under the heading, *excluding* the `Labels` and `Milestone` lines. Checkboxes written as `- [ ]` become clickable in the issue.
4. In the side panel: set **Labels** (one `type/…` and one `epic/…`) and **Milestone**.
5. Click **Create**. Note the number GitHub assigns. It won't match the `Issue n` numbering here; use GitHub's number from now on.

Create them in the suggested order below, so the numbers roughly follow the order of work.

### Step 4 — Check the result

Open **Milestones** → `Sprint 1 — Walking skeleton`. It should list 10 open issues at 0%. From here on, `docs/working-agreements.md` §4 describes how to work an issue from start to close.

## Suggested order

1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9. Spike S-2 (10) must finish before the bootstrap story (8). Spike S-6 (2) comes early because the quality gate (9) depends on it.

## Issues

### Issue 1: Scaffold the repository layout and hygiene files
- **Labels:** type/chore, epic/release
- **Milestone:** Sprint 1 — Walking skeleton

**Why.** Every later story needs the directory layout from ADR-0001, and the public repo needs its hygiene files from the first commit (NFR-3, NFR-6).

**Tasks**
- Create the directories from `docs/architecture.md` §2 (empty ones get a `.gitkeep`).
- `.gitignore` including `.env` and `.DS_Store` (FR-3.1).
- `.env.example` documenting `COMPUTER_NAME`, `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, each with a one-line comment (FR-3.1).
- `LICENSE`: MIT (DEC-36), with the copyright line naming the GitHub username only (NFR-3).
- `README.md` stub: one-paragraph purpose, "under construction" status, the instruction to update macOS first (CR-13), and the bootstrap command from ADR-0003.
- Commit the charter documents under `docs/`.

**Acceptance criteria**
- [ ] The tree matches `docs/architecture.md` §2 for every directory that exists in sprint 1.
- [ ] Creating an empty `.env` and running `git status` does not list it (FR-3.1).
- [ ] `.env.example` contains the three keys, with comments, and no real values (NFR-3).

### Issue 2: Spike S-6 — choose a zsh test framework
- **Labels:** type/spike, epic/engine
- **Milestone:** Sprint 1 — Walking skeleton

**Question.** Which test framework runs fixture tests against zsh functions on macOS 27 with the least friction?

**Time-box.** One working session. Read-only on the Mac apart from installing the candidate tools.

**Candidates.** bats-core (tests in bash, driving zsh through subprocesses) and zsh-native frameworks such as ZUnit. Check each one's current maintenance status and documentation; don't rely on memory.

**Output**
- `docs/spikes/S-6-test-framework.md`: candidates compared on maintenance, zsh support, install path (Homebrew or vendored), and a sample test of a pure function.
- ADR-0004 updated with the choice.

**Acceptance criteria**
- [ ] One framework chosen, with the reason and the rejected alternatives recorded in ADR-0004.
- [ ] A sample test runs green on the Mac.

### Issue 3: Logging library — table-driven `log` function
- **Labels:** type/story, epic/engine
- **Milestone:** Sprint 1 — Walking skeleton

**Story.** As the stakeholder, I want every line the program prints to follow one format, so that a converged run reads as a quiet column of `OK`s and anything in color needs my attention.

**Scope.** `lib/log.zsh` per ADR-0009 and `docs/architecture.md` §7: `log_start`, `log`, `log_finish`, and the status table.

**Acceptance criteria**
- [ ] Every line follows `HH:MM:SS  STATUS   [module]  subject: message` (§8.5, FR-15.4).
- [ ] `log` accepts exactly the statuses `OK`, `CHANGED`, `DIFF`, `FAIL`, `WARN`, `ACTION`, `NOTE` (CR-18); any other status prints a `FAIL` naming it.
- [ ] `log_start` and `log_finish` print the start and finish headers, and the finish header carries changed, ok and failed counts (FR-15.5).
- [ ] `FAIL` lines go to stderr; all other lines go to stdout (§8.5).
- [ ] Color appears only when the stream is a terminal and `NO_COLOR` is unset or empty; without color, every line still reads correctly (FR-15.7).
- [ ] Fixture tests cover each status, the headers, an unknown status, and color on and off.

### Issue 4: Converge helper — check → apply → verify, one line per item
- **Labels:** type/story, epic/engine
- **Milestone:** Sprint 1 — Walking skeleton

**Story.** As the stakeholder, I want every managed item handled the same way, so that re-running is always safe and `--check` can never change anything.

**Scope.** `lib/converge.zsh` per `docs/architecture.md` §6.

**Acceptance criteria**
- [ ] An item already in the desired state emits one `OK` line, and apply is never called (FR-14.1).
- [ ] A changed item emits one `CHANGED` line, only after the read-back confirms the effect (CR-18).
- [ ] A failed apply emits one `FAIL` naming the item and a remedy; a failed read-back emits one `FAIL` with expected and found values (FR-15.1).
- [ ] With `CHECK_MODE=1`, an item that differs emits one `DIFF` line and apply is never called (CR-5).
- [ ] Counters update for changed, ok, failed and would-change.
- [ ] Fixture tests cover all five outcomes, using stub check, apply and verify functions.

### Issue 5: `bin/provision` entry point runs stages and prints a summary
- **Labels:** type/story, epic/engine
- **Milestone:** Sprint 1 — Walking skeleton

**Story.** As the stakeholder, I want one command that runs every stage in order and ends with a summary, so that I can tell at a glance what changed and whether anything failed.

**Scope.** Option parsing, the explicit stage array (sprint 1 contains `preflight` and `defaults` only), exit codes, and the run summary.

**Acceptance criteria**
- [ ] `bin/provision --help` prints usage; an unknown option prints usage and exits 64.
- [ ] `--check` sets check mode for every stage (CR-5); `--upgrade` is accepted and documented as affecting runtimes only (CR-11).
- [ ] Stages run in array order; a stage returning 1 or 2 stops the run, and the summary still prints (FR-15.3).
- [ ] The summary shows total changed, ok and failed counts (FR-15.3), and in check mode the would-change count (CR-5).
- [ ] Exit codes follow `docs/architecture.md` §3.
- [ ] The script uses `#!/bin/zsh -f` and the strict-mode options confirmed in ADR-0002 (DEC-18, DEC-19).

### Issue 6: Preflight — Apple Silicon and supported macOS tiers
- **Labels:** type/story, epic/preflight
- **Milestone:** Sprint 1 — Walking skeleton

**Story.** As the stakeholder, I want the run to refuse unsupported hardware and macOS versions before it changes anything, so that it never half-configures a machine it was not built for.

**Scope.** FR-2.1 and FR-2.2 with CR-1's tiers. FR-2.3 (admin password) is sprint 2.

**Acceptance criteria**
- [ ] Apple Silicon is detected in a way that is still correct when the terminal runs under Rosetta; on Intel, the run exits with a named message and exit code 2 (FR-2.1).
- [ ] macOS 27 → `OK`; macOS 26 → `WARN` that the version is unverified, then continue; any other version → `FAIL` and exit, before any change (FR-2.2, CR-1).
- [ ] The version parser is a pure function, fixture-tested with 26.x, 27.x, 15.x and 28.0 inputs.
- [ ] No system change happens before preflight passes, apart from the bootstrap's Command Line Tools install (FR-2, CR-15).

### Issue 7: First managed item — the screenshot folder
- **Labels:** type/story, epic/settings
- **Milestone:** Sprint 1 — Walking skeleton

**Story.** As the stakeholder, I want the program to create `~/Desktop/Screenshots` when it is missing, so that the whole pipeline is proven on one real, harmless change.

**Why this item.** It is the smallest real change in the PRD (FR-10.4), it is easy to undo by hand, and it exercises every converge outcome.

**Acceptance criteria**
- [ ] Missing folder → one `CHANGED` line, and the folder exists afterwards (FR-10.4, CR-18).
- [ ] Existing folder → one `OK` line (FR-14.1).
- [ ] A regular *file* at that path → `FAIL` naming the path and the remedy; the file is not touched (FR-14.2, FR-15.1).
- [ ] With `--check` and the folder missing → one `DIFF` line; nothing is created (CR-5).
- [ ] The second consecutive run makes zero changes (M3).

### Issue 8: Bootstrap loader — one pasted command starts a run
- **Labels:** type/story, epic/bootstrap
- **Milestone:** Sprint 1 — Walking skeleton

**Story.** As the stakeholder, I want to start a run by pasting one command into Terminal, so that a fresh Mac needs nothing installed first.

**Scope.** `bootstrap.zsh` per ADR-0003, including the Command Line Tools install and the clone (CR-15).

**Depends on.** Spike S-2 (install method).

**Acceptance criteria**
- [ ] The documented command `/bin/zsh -f -c "$(curl -fsSL https://raw.githubusercontent.com/panningforbacon/dotfiles/main/bootstrap.zsh)"` starts a run (FR-1.1).
- [ ] With an existing checkout at `$DOTFILES_DIR`, the loader runs that checkout as it stands, including uncommitted edits, and never pulls (FR-1.3, CR-6).
- [ ] With `DOTFILES_DIR` pointing to an empty temporary directory, the loader clones the repo there and runs it.
- [ ] If the Command Line Tools are missing, the loader starts their installer, prints one `ACTION` line, and continues once they are installed (FR-1.2, CR-15). *Verified by code review and at the release wipe; the tools are already installed on the development Mac.*
- [ ] Arguments pass through: `… bootstrap.zsh)" bootstrap --check` runs in check mode.
- [ ] A failed download or clone prints a `FAIL` line in §8.5 format with a remedy, and exits 1.
- [ ] Prompts still read from the keyboard, proving stdin is not consumed.

### Issue 9: `scripts/check` runs the DoD quality gate
- **Labels:** type/chore, epic/release
- **Milestone:** Sprint 1 — Walking skeleton

**Why.** CR-7 replaced ShellCheck with `zsh -n` plus the fixture test suite. Both need one command so every story can run the gate.

**Depends on.** Spike S-6.

**Acceptance criteria**
- [ ] `scripts/check` runs `zsh -n` on `bootstrap.zsh`, everything in `bin/`, `lib/`, `modules/` and `scripts/`, and the zsh dotfiles under `home/`.
- [ ] It runs the whole test suite with the framework chosen in S-6.
- [ ] It exits non-zero if either step fails, and names the failing file or test.
- [ ] `README.md` documents how to run it.

### Issue 10: Spike S-2 — Command Line Tools install and sudo keep-alive
- **Labels:** type/spike, epic/bootstrap
- **Milestone:** Sprint 1 — Walking skeleton

**Questions**
1. On macOS 27, should the bootstrap install the Command Line Tools with `xcode-select --install` (Apple's dialog, one manual stop) or with the headless method Homebrew's installer uses? What exactly does Homebrew's current installer do, and how does the bootstrap detect when the install has finished?
2. With a sudo ticket refreshed in the background, does the Homebrew installer, and a cask that calls `sudo`, run without a second prompt (FR-2.3, ADR-0008)?

**Time-box.** One working session. **Read-only on system state.** The Command Line Tools are already installed on this Mac, so question 1 is answered from Homebrew's installer source and Apple's documentation. Question 2 is tested with a harmless `sudo -n true` after the ticket's normal expiry.

**Output.** `docs/spikes/S-2-clt-and-sudo.md`, with findings and the effect on the manual-stop count (M2).

**Acceptance criteria**
- [ ] Both questions answered, with sources or observed output.
- [ ] ADR-0003 and ADR-0008 updated if the findings change them.

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | First draft: 12 issues, created by script. |
| 1.0 | 2026-09-28 | License confirmed as MIT. |
| 0.2 | 2026-09-28 | Manual creation walkthrough replaces the script (DEC-32). 10 issues: S-3 and S-5 cancelled; logging, converge, preflight and bootstrap issues updated for CR-15 and CR-18. |

# Architecture

| | |
| --- | --- |
| **Status** | Charter v1.0 — **accepted** by PO, 2026-09-29 |
| **Requirements** | `docs/prd.md` v1.4 (change requests CR-1 to CR-18 merged) |
| **Decisions** | Reasoning for every choice below is in `docs/adr/`. Index in §10. |

## 1. Overview

A zsh program that takes an Apple Silicon Mac from first desktop to fully configured, and converges it back to the declared state on every re-run. It has three layers:

- **Data:** `Brewfile`, `macos/defaults.conf`, the files under `home/`, and the per-machine `.env`. Editing data is how the user changes the machine (NFR-4).
- **Modules:** one per run stage. A module knows *what* its stage manages and reads its data.
- **Library (`lib/`):** mechanism shared by all modules: logging, the converge contract, privileges, prompts. It knows nothing about what is managed.

## 2. Repository layout

The repo is `github.com/panningforbacon/dotfiles`, checked out at `~/.dotfiles` (ADR-0001).

```
dotfiles/
├── bootstrap.zsh              # target of the pasted command; loader only (ADR-0003)
├── bin/
│   └── provision              # the entry point for every run
├── lib/                       # mechanism; no knowledge of managed items
│   ├── log.zsh                # the only code that prints (ADR-0009)
│   ├── converge.zsh           # check → apply → verify (§6)
│   ├── sudo.zsh               # admin ticket keep-alive (ADR-0008)
│   └── prompt.zsh             # manual stops: wait-for-Enter and bail-out
├── modules/                   # policy; one file per stage (§4)
│   ├── preflight.zsh
│   ├── inputs.zsh
│   └── …
├── Brewfile                   # package manifest; setup notes and the iCloud reminder as comments (ADR-0005)
├── macos/
│   └── defaults.conf          # settings manifest (ADR-0006)
├── home/                      # mirrors $HOME; every file here is linked (ADR-0007)
│   ├── .zshrc
│   ├── .zprofile
│   ├── .zsh_plugins.txt       # antidote plugin list
│   └── .config/
│       ├── starship.toml
│       ├── mise/config.toml
│       ├── uv/uv.toml
│       ├── git/config         # shared git settings; includes the generated identity file
│       ├── ghostty/           # file name per current Ghostty docs (verified in its story)
│       └── nvim/init.lua
├── templates/
│   └── git-identity.tmpl      # rendered with .env values into ~/.config/git/identity
├── tests/
│   ├── fixtures/              # captured command output
│   └── …                      # framework chosen by spike S-6 (ADR-0004)
├── scripts/
│   └── check                  # DoD gate: zsh -n on every script + test suite (CR-7)
├── docs/
│   ├── prd.md
│   ├── prd-v1.4-change-requests.md
│   ├── architecture.md
│   ├── release-plan.md
│   ├── working-agreements.md
│   ├── adr/
│   ├── backlog/
│   └── spikes/                # one findings file per spike
├── .env.example               # documents every per-machine key (FR-3.1)
├── .gitignore                 # includes .env
├── LICENSE
└── README.md
```

## 3. Entry points

**The pasted command** (FR-1.1):

```sh
/bin/zsh -f -c "$(curl -fsSL https://raw.githubusercontent.com/panningforbacon/dotfiles/main/bootstrap.zsh)"
```

`bootstrap.zsh` is a loader, not the provisioner (ADR-0003):

1. If `$DOTFILES_DIR` (default `~/.dotfiles`) contains `bin/provision`, run it as it stands. Never pull (CR-6).
2. Otherwise:
   1. if the Xcode Command Line Tools are missing, start Apple's installer and wait until they are installed (one manual stop, CR-15);
   2. `git clone` the repo into `$DOTFILES_DIR`;
   3. run `bin/provision` from the new checkout.

Arguments after the command are passed through, for example `… bootstrap.zsh)" bootstrap --check`.

**`bin/provision [--check] [--upgrade] [--help]`**

| Option | Effect | Requirement |
| --- | --- | --- |
| *(none)* | Converge the machine to the declared state | FR-1.3 |
| `--check` | Run every check, no apply, no manual stops; report `DIFF` lines | CR-5 |
| `--upgrade` | Also upgrade mise runtimes to the latest patch within each declared version | CR-11 |
| `--help` | Print usage | — |

**Exit codes**

| Code | Meaning |
| --- | --- |
| 0 | Run completed; no `FAIL` |
| 1 | At least one `FAIL` (FR-15.1) |
| 2 | Bail-out: the user must act, then re-run (FR-2) |
| 64 | Usage error |

## 4. Run stages

`bin/provision` holds the stage order as an explicit array. It does not rely on file-name ordering.

| # | Stage | Module | Requirements | May stop the run |
| --- | --- | --- | --- | --- |
| 1 | Preflight | `preflight` | FR-2.1–2.3, CR-1 | Bail-outs; admin password prompt |
| 2 | Per-machine inputs | `inputs` | FR-3 | One prompt for missing `.env` keys |
| 3 | Security baseline | `security` | FR-5 | No (FileVault is a warning) |
| 4 | Packages and apps | `brew` | FR-6, CR-8, CR-10, CR-11 | No |
| 5 | Runtimes | `runtimes` | FR-7, FR-12 | No |
| 6 | Dotfiles | `dotfiles` | FR-8, CR-14 | No |
| 7 | Identity | `identity` | FR-9 | GitHub login; SSH passphrase (first run) |
| 8 | macOS settings | `defaults` | FR-10, CR-12, CR-16 | No |
| 9 | Summary | *(provision)* | FR-13, FR-15.3 | No |

Any stage returning 1 or 2 ends the run. The summary still prints (FR-15.3).

**Expected manual stops on a fresh run:** Command Line Tools installer (1), admin password (1), per-machine inputs (1), GitHub login (1), SSH passphrase (1). Five, against a budget of 12 (M2).

## 5. Module boundaries

- Each module is `modules/<name>.zsh` and defines one public function, `mod_<name>_run`, which returns 0 (completed), 1 (failed) or 2 (bail-out).
- Modules **never print directly**; every line goes through `lib/log.zsh`.
- Modules **never call each other**. They share state only through variables set by earlier stages: `DOTFILES_DIR`, `CHECK_MODE`, `UPGRADE_MODE`, and the `.env` values loaded by `inputs`.
- Every system change happens inside an **apply** function passed to `converge` (§6). This is what makes `--check` safe by construction.
- Modules read their data files directly. They do not interpret each other's data.

## 6. The converge contract: check → apply → verify

Every managed item goes through one helper:

```zsh
converge <subject> <desired> <remedy> <check_fn> <apply_fn> <verify_fn> [args...]
```

`desired` is the state the read-back must find, for example `present`. `remedy` is what the user should do after a `FAIL`, for example `move the file aside, then re-run`. Both appear only in `FAIL` lines.

| Function | Returns | Prints to stdout |
| --- | --- | --- |
| `check_fn args` | 0 = already in the desired state | the observed state, e.g. `missing` or `present` |
| `apply_fn args` | 0 = the command succeeded | the past-tense result, e.g. `created` |
| `verify_fn args` | 0 = read-back confirms the desired state | the state found, e.g. `present` |

Each function runs in a subshell, receives `args`, and has its stdout and stderr captured and joined into one line, so nothing reaches the terminal except through `log`. A function therefore cannot pass state to the next one except through `args`. An apply that fails without printing anything is reported as `<apply_fn> exited <n>`.

Each item produces **exactly one line** (CR-18):

| Outcome | Line | Counter |
| --- | --- | --- |
| check returns 0 | `OK  subject: already <state> — skipping` | ok |
| check ≠ 0, `--check` mode | `DIFF  subject: <observed> — would change` | would change |
| check ≠ 0, apply and verify succeed | `CHANGED  subject: <result> — verified` | changed |
| apply ≠ 0 | `FAIL  subject: <what failed> — <remedy>` | failed |
| verify ≠ 0 | `FAIL  subject: expected <desired>, found <observed> — <remedy>` | failed |

Rules (FR-14):

- Check always runs first. Apply runs only when check says the state differs (FR-14.1).
- A module only ever converges items it declares. Nothing undeclared is removed or reset (FR-14.2).
- Every apply is safe to repeat, so interrupting and re-running converges (FR-14.3).
- `CHANGED` is only printed after the read-back confirms the effect. A command that succeeded but had no effect is a `FAIL` (FR-10.2, M4).
- `converge` returns 0 for `OK`, `DIFF` and `CHANGED`, and 1 for `FAIL`. Whether to continue with the next item is the module's decision.
- Check mode is on when `CHECK_MODE` is set to anything other than empty or `0`, so a mistyped value errs toward changing nothing.
- A wrong argument count or a name that is not a defined function is itself a `FAIL`, checked before anything runs, including in check mode.

Three documented exceptions keep the same contract but change the output:

- **Homebrew** (CR-10, ADR-0005): the whole Brewfile is one item. Check is `brew bundle check`; apply is `brew bundle`, whose output passes through unmodified; verify is `brew bundle check` again. Because Homebrew upgrades by default (CR-11), check fails whenever anything is outdated.
- **macOS settings** (§8.5 compact form, ADR-0006): one dot-padded line per intent, with current and desired values. The `defaults` module formats that message; the status is still `OK`, `CHANGED`, `DIFF` or `FAIL`.
- **Manual stops**: `lib/prompt.zsh` offers `wait_for_user <message>` (print `ACTION`, wait for Enter) and `bail <message>` (print `ACTION`, return 2). In `--check` mode, stops are reported as `DIFF` and never wait.

## 7. Logging implementation

`lib/log.zsh` is the only code that writes to the terminal (FR-15.4, ADR-0009). It exposes three functions:

```zsh
log_start <module> <item-count>        # ▶ header; sets the current module
log <STATUS> <subject> <message>       # every other line; an empty subject prints the message alone
log_finish                             # ■ header with this module's counts
```

- **Status table.** One associative array maps each status to its stream, color and counter. Adding a status means adding one row. An unknown status is itself a `FAIL`, so typos fail loudly.

  | Status | Stream | Color | Counter |
  | --- | --- | --- | --- |
  | `OK` | stdout | dim | ok |
  | `CHANGED` | stdout | green | changed |
  | `DIFF` | stdout | cyan | would change |
  | `FAIL` | stderr | red | failed |
  | `WARN` | stdout | yellow | — |
  | `ACTION` | stdout | bold magenta | — |
  | `NOTE` | stdout | none | — |

- **Line anatomy:** `HH:MM:SS  STATUS   [module]  subject: message`. STATUS is padded to 7 columns and `[module]` to 16, each followed by two spaces; a longer module name is never truncated. The time comes from zsh's `strftime` (the `zsh/datetime` module), so no `date` process is spawned per line.
- **Current module:** `LOG_MODULE`, default `provision`. `log_start` sets it; lines outside any module, such as the run summary, set it directly.
- **Misuse:** an unknown status or a wrong argument count prints one `FAIL`, counts as failed, and returns 1.
- **Color** (FR-15.7): enabled per stream only if that stream is a terminal and `NO_COLOR` is unset or empty. Color covers the whole line; headers are bold. When color is off, the `brew` module also exports `HOMEBREW_NO_COLOR=1` (DEC-28).
- **Counters:** `LOG_COUNTS`, keyed `module:counter` (`ok`, `changed`, `would_change`, `failed`); `log_start` zeroes the module's counters. Module finish lines and the run summary read the same array, so they cannot disagree.
- **Secrets:** no secret is ever passed to `log`. Passphrase prompts use non-echoing input (FR-15.8).
- **No log files** (FR-15.2). Users who want a record can pipe through `tee`.

## 8. Configuration and state

| What | Where | Tracked in git | Requirement |
| --- | --- | --- | --- |
| Packages and apps | `Brewfile` | yes | FR-6, CR-8 |
| Manual setup reminders, incl. iCloud | comments in `Brewfile` | yes | FR-13.1, CR-17 |
| macOS settings | `macos/defaults.conf` | yes | FR-10 |
| Dotfiles | `home/` → linked into `$HOME` | yes | FR-8 |
| Runtime versions | `home/.config/mise/config.toml` | yes | FR-7.3 |
| Per-machine values | `.env` (repo root) | **no** | FR-3 |
| Git identity | `~/.config/git/identity`, rendered from `templates/` + `.env` | no (generated) | FR-9.4 |
| SSH passphrase | macOS Keychain | no | FR-9.5 |

## 9. Privileges

Preflight asks for the admin password once (`sudo -v`). A background loop refreshes the sudo ticket about every 60 seconds and stops when the run ends. Only commands that need root use `sudo`; the program itself never runs as root, because Homebrew refuses to. Details and rejected alternatives: ADR-0008.

## 10. ADR index

| ADR | Title | Status |
| --- | --- | --- |
| 0001 | Repository name and layout | Accepted |
| 0002 | Implementation language: zsh | Accepted (PO override) |
| 0003 | Bootstrap loader and entry point | Accepted |
| 0004 | Test environment and strategy | Accepted; framework: ShellSpec (S-6) |
| 0005 | Homebrew integration via Brewfile | Accepted (PO override) |
| 0006 | macOS settings manifest format | Accepted (PO override) |
| 0007 | Dotfile linking mechanism | Accepted |
| 0008 | Admin privileges for the whole run | Accepted |
| 0009 | Logging library structure | Accepted |

## 11. Charter decision log

`DEC` IDs are referenced by the ADRs and change requests. "PO" means a Product Owner decision or override; "TL" means tech lead.

| ID | Decision | By | Recorded in |
| --- | --- | --- | --- |
| DEC-1 | Supported macOS: 26 and 27; 15 dropped | PO | CR-1 |
| DEC-2 | The daily Mac is upgraded before any project code runs on it | PO | — |
| DEC-3 | No VMs; the daily Mac is the only test environment; gaps accepted | PO | CR-2, ADR-0004 |
| DEC-4 | The stakeholder owns exactly one Mac | PO | CR-2 |
| DEC-5 | *Withdrawn with CR-3* (multi-major bail rule) | PO | CR-13 |
| DEC-6 | Two tiers: 27 verified, 26 tolerated with a warning | PO | CR-1 |
| DEC-7 | Fresh-run evidence from one planned wipe at release | PO | CR-4 |
| DEC-8 | Check mode in v1 as a SHOULD | PO | CR-5 |
| DEC-9 | Upgrade the Mac to 27 before sprint 1 starts | PO | — |
| DEC-10R | zsh 5.9 for all code (overrides DEC-10, bash 3.2) | PO | ADR-0002 |
| DEC-11 | The bootstrap is a loader, not the provisioner | TL | ADR-0003 |
| DEC-12 | *Withdrawn* (ShellCheck scope) | PO | CR-7 |
| DEC-13 | A re-run executes the local checkout as it stands; never pulls | PO | CR-6, ADR-0003 |
| DEC-14 | Repo `panningforbacon/dotfiles` | PO | ADR-0001 |
| DEC-15 | Checkout at `~/.dotfiles` | PO | ADR-0001 |
| DEC-16R | Brewfile is the package manifest; notes are comments (overrides DEC-16) | PO | CR-8, ADR-0005 |
| DEC-17R | Settings file mimics `defaults write` syntax (overrides DEC-17) | PO | ADR-0006 |
| DEC-18 | Scripts use `#!/bin/zsh -f`; functions start with `emulate -L zsh` | TL | ADR-0002 |
| DEC-19 | Strict-mode options, confirmed against the zsh 5.9 manual | TL | ADR-0002 |
| DEC-20R | Homebrew's own behavior and output; Brewfile is one logged item (overrides DEC-20) | PO/TL | CR-10, ADR-0005 |
| DEC-21R | No filtering of Brewfile entry types; rule stated in a Brewfile comment (overrides DEC-21) | PO/TL | ADR-0005 |
| DEC-22 | `# area: intent` headers group settings lines; free comments use `##` | TL | ADR-0006 |
| DEC-23 | `[logout]` flag on the header (the `[fda]` flag was removed with CR-12) | TL | ADR-0006 |
| DEC-24 | *Withdrawn:* `@function` escape hatch; no remaining row needs it | TL | ADR-0006 |
| DEC-25 | Settings lines are parsed, never `eval`ed | TL | ADR-0006 |
| DEC-26 | sudo keep-alive | TL | ADR-0008 |
| DEC-27 | Single logging library | TL | ADR-0009 |
| DEC-28 | `HOMEBREW_NO_COLOR` follows our color decision | TL | ADR-0005 |
| Q16 | Homebrew upgrades on every run | PO | CR-11 |
| DEC-29 | Logging API is one table-driven `log STATUS subject message` function, plus start and finish headers | PO/TL | ADR-0009 |
| DEC-30 | Reduced status vocabulary: one line per item | PO | CR-18, ADR-0009 |
| DEC-31 | Scope cuts: Safari/FDA, macOS updates, template defaults, tarball path, three ⚠ settings, iCloud stop | PO | CR-12 to CR-17 |
| DEC-32 | GitHub Issues are created and processed by hand, no automation | PO | `docs/working-agreements.md` §4 |
| DEC-33 | Only `type/…` labels up front; an `epic/…` label is created the first time an issue needs it | TL | `docs/working-agreements.md` §4 |
| DEC-34 | mise runtimes upgrade only with `--upgrade`; Homebrew upgrades every run | PO | CR-11 |
| DEC-35 | Dotfile linking per ADR-0007: own code, one symlink per file, git config split | PO | ADR-0007 |
| DEC-36 | License: MIT | PO | `LICENSE` (sprint 1, issue 1) |

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | First draft from charter rounds 1–5. |
| 0.2 | 2026-09-28 | Applied CR-12 to CR-18 and DEC-29 to DEC-33: fewer stages, one-line-per-item converge, table-driven logging, clone-based bootstrap. |
| 1.0 | 2026-09-29 | Resolved the last open items: DEC-34 to DEC-36; ADR-0007 accepted. Charter accepted by PO. |

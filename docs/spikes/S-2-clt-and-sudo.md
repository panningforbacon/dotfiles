# Spike S-2: Command Line Tools install and sudo keep-alive

| | |
| --- | --- |
| **Issue** | #10 |
| **Date** | 2026-10-02 |
| **Status** | Complete. Probe run on the Mac 2026-10-03. |
| **Related** | FR-1.2, FR-2.3, FR-6.2, FR-15.8, M2; ADR-0003, ADR-0005, ADR-0008; CR-15 |

## Answers

1. **Command Line Tools: keep `xcode-select --install`.** The headless method saves at most one manual stop, needs root before preflight, and rests on an undocumented trigger that Homebrew itself backs with a fallback. Tighten the completion check (below).
2. **Sudo keep-alive: holds for our own `sudo` calls and for the Homebrew installer. It does not survive `brew`.** Homebrew deliberately resets the sudo timestamp. The installed release (7.0.2) does it at the start of every `brew` command; unreleased `main` does it only before `brew`'s first `sudo` call. Either way a `pkg` cask prompts for the password (in §8.1: `microsoft-office`), and on 7.0.2 our own ticket is gone after any `brew` command.

**Effect on M2:** 5 expected stops become 6, against a budget of 12, provided every stage of ours that needs root runs before the first `brew` command. Each root stage after it adds a stop. M2 is met. FR-2.3 ("no second password prompt") is not, as written. That needs a PO decision (see Decisions needed).

## Limits of this spike

- **The Mac is on macOS 26, not 27.** ADR-0004 says it was upgraded before sprint 1 (DEC-9). Nothing here is observed on macOS 27.
- Nothing was installed. The Command Line Tools install path and the Homebrew install are read from source, not run. They first run for real at the release wipe (ADR-0004).
- The `brew` finding is from source at two points: the installed release and `main`. The first draft of this file read only `main`; the probe's `grep` for `utils/sudo.sh` failed on the Mac because that file does not exist in 7.0.2, which exposed the gap.

## Sources

| Source | Pinned at |
| --- | --- |
| Homebrew installer, `install.sh` | Homebrew/install `35da6871`, file sha256 `5f333bbe…08ccb148` |
| `brew` release: `Library/Homebrew/brew.sh`, `system_command.rb` | Homebrew/brew tag `7.0.2` (installed on the Mac); reset also present in `7.0.7` |
| `brew` unreleased: `Library/Homebrew/utils/sudo.sh`, `system_command.rb`, `cask/artifact/pkg.rb` | Homebrew/brew `main` at `2170a64c` |
| Cask definitions | Homebrew/homebrew-cask `8d9df9ae` |
| Apple, "Installing the command-line tools" | developer.apple.com/documentation/xcode/installing-the-command-line-tools |

## Question 1: Command Line Tools

### What Homebrew's installer does

- **When** (`install.sh` lines 446–452): `/Library/Developer/CommandLineTools/usr/bin/git` does not exist, and sudo access is available.
- **Headless attempt** (lines 885–909):
  1. `sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress`. The file makes `softwareupdate` list the Command Line Tools.
  2. `softwareupdate -l`, filtered to labels containing `Command Line Tools`, version-sorted, last one taken.
  3. `sudo softwareupdate -i "<label>"`. This blocks until the install ends.
  4. `sudo xcode-select --switch /Library/Developer/CommandLineTools`.
  5. An exit trap removes the placeholder file.
  6. On any failure it warns and carries on.
- **Fallback** (lines 911–921), only when stdin is a terminal and the tools are still missing: `xcode-select --install`, then "Press any key when the installation has completed", then the same `--switch`.

### How completion is detected

Homebrew does not poll. The headless path is synchronous, and the fallback asks the human. Either way, the test afterwards is the existence of the `git` binary above, not `xcode-select -p`.

### Why not headless

- **It needs root in the loader.** Three of its steps use `sudo`. That puts a password prompt before preflight, where FR-2.3 puts it, and before `lib/sudo.zsh` exists on disk. The download outlasts a sudo ticket, so preflight would likely prompt again unless the loader carried its own keep-alive.
- **It is undocumented.** Apple documents `xcode-select --install`. The placeholder file appears in no Apple documentation I found; the only evidence for it is Homebrew's source, which treats it as fallible.
- **It saves one stop of twelve**, and swaps it for an earlier password prompt.
- **It would change the PRD.** FR-1.2 says the install "opens Apple's installer dialog".
- **Neither path can be tested before the release wipe.** The simpler one is the smaller risk.

### Changes recommended to ADR-0003, step 2.1

- **Wait for the `git` binary, not for `xcode-select -p`.** Poll until `/Library/Developer/CommandLineTools/usr/bin/git` is executable. It is the thing the next step needs, and it is Homebrew's test. Whether `xcode-select -p` can succeed mid-install is unverified; this check makes the question moot.
- **Never run `/usr/bin/git` to test.** On a Mac without the tools, the stub opens the install dialog itself.
- **Say how to recover from a cancelled dialog.** `xcode-select --install` returns at once and the dialog can be dismissed. The `ACTION` line must tell the user to press Ctrl-C and re-run. Without it the loader waits forever.

## Question 2: sudo keep-alive

### Homebrew installer: no second prompt

With `NONINTERACTIVE=1` (ADR-0005) and a live ticket:

- **Access check** (lines 287–344): `sudo -n -l mkdir`. With `-n` it can never prompt. With a live ticket it succeeds; without one the installer aborts.
- **Detection call** (line 314): `sudo -n -k -l`. Combined with another option, `-k` ignores the cached ticket for that one call and leaves it in place.
- **Exit trap** (lines 328–332): the installer runs `sudo -k` on exit only if no ticket was live when it started. With our ticket live, the trap is never set.
- **Real work** (`execute_sudo`, lines 372–391): plain `sudo`, which finds the live ticket.

### `brew`: the ticket is reset, by design

- **Release 7.0.2 (installed).** `brew.sh` lines 649–653 run `sudo --reset-timestamp` on every `brew` command, commented "Reset sudo timestamp to avoid running unauthorized sudo commands". Only the fast-path commands handled earlier in `brew.sh` (such as `shellenv`, `--prefix`, `--repository`, `--version`) exit before it. Release 7.0.7 still has the reset in `brew.sh` (line 670); its exact conditions were not read.
- **Unreleased `main`.** The reset moved to `utils/sudo.sh` and runs once per `brew` process, the first time a command needs sudo (`SystemCommand.sudo_available?`).
- **Casks.** A `pkg` cask runs `/usr/sbin/installer` with `sudo: true` (`cask/artifact/pkg.rb`). With the ticket reset, `sudo -u root -E -- installer …` prompts.
- **Our keep-alive cannot recover:** `sudo -n -v` fails without a ticket.
- **The Homebrew installer ends by running `brew`**, so on 7.0.2 the ticket is gone once the installer finishes.

**Inventory check (§8.1, casks at the pinned commit).**

| Cask | Artifact | Needs root |
| --- | --- | --- |
| `microsoft-office` | `pkg` | Yes |
| `ghostty`, `visual-studio-code`, `docker-desktop`, `google-chrome`, `duckduckgo`, `spotify`, `bitwarden`, `notion`, `rectangle`, `bartender` | `app` | No |

### Consequences for `lib/sudo.zsh`

- Treat the ticket as dead after any `brew` command that is not a fast-path one, including the Homebrew install itself.
- Every stage of ours that needs root (firewall, computer name, settings that need root) must run **before** the first such `brew` command, or it prompts again.
- The keep-alive only needs to live until that point.

## Decisions needed

FR-2.3 cannot be met as written while a `pkg` cask is in the inventory.

| Option | Verdict |
| --- | --- |
| **A. Amend FR-2.3:** our code asks once; Homebrew may ask once more for each package that needs root. | **Recommended.** One extra stop, M2 still met. Needs a change request. |
| B. Give `sudo` the password through `SUDO_ASKPASS`. | Rejected: our code would handle the password, against ADR-0008. |
| C. Pre-set `HOMEBREW_SUDO_CHECKED=1` to skip the reset. | Rejected: an internal variable, and it switches off a Homebrew security measure. Not verified to work. |
| D. Temporary passwordless rule in `/etc/sudoers.d`. | Already rejected in ADR-0008. |
| E. Install `microsoft-office` outside the Brewfile. | Rejected: breaks FR-6.2. |

## Probe

Run on the Mac. About 11 minutes, two password prompts. Output uses `print`, not `lib/log.zsh`, because this is not project code.

```zsh
#!/bin/zsh -f
# Throwaway probe for spike S-2. Not project code: output skips lib/log.zsh.
# Touches only sudo's own timestamp record, and clears it on exit.

emulate -R zsh                      # idiom: reset options to zsh defaults at script top level
SUDO=${SUDO:-/usr/bin/sudo}         # idiom: ${var:-default}; overridable so a stub can test the flow
WAIT=${WAIT:-330}                   # sudo's default ticket lifetime is 300 s; wait past it
keepalive_pid=

# expect ok|fail <label> <command...>: run the command, compare its exit status with the prediction.
expect() {
  emulate -L zsh
  local want=$1 label=$2 got=fail
  shift 2
  "$@" >/dev/null 2>&1 && got=ok    # idiom: "$@" runs the remaining arguments as a command
  if [[ $got == $want ]]; then
    print -r -- "PASS  $label (got $got)"
  else
    print -r -- "MISS  $label (wanted $want, got $got)"
  fi
}

# Sleep in 30 s slices and say so, so a long wait is not mistaken for a hang.
wait_past_expiry() {
  emulate -L zsh
  local left=$WAIT
  while (( left > 0 )); do          # idiom: (( )) is arithmetic evaluation; true when non-zero
    print -r -- "  waiting, $left s left"
    sleep $(( left < 30 ? left : 30 ))
    (( left -= 30 ))
  done
}

keepalive() {
  emulate -L zsh
  # $$ stays the main script's PID inside a background subshell, so kill -0 is the
  # parent liveness check from ADR-0008. idiom: kill -0 tests "does this PID exist".
  while kill -0 $$ 2>/dev/null; do
    $SUDO -n -v 2>/dev/null || break
    sleep 60
  done
}

# idiom: TRAPEXIT is zsh's named exit trap; defined at top level it runs when the script exits.
TRAPEXIT() {
  [[ -n $keepalive_pid ]] && kill $keepalive_pid 2>/dev/null
  $SUDO -k
}
TRAPINT() { exit 130 }              # Ctrl-C still goes through TRAPEXIT

print -r -- "== facts"
print -r -- "macOS $(sw_vers -productVersion 2>/dev/null), zsh $ZSH_VERSION, tty $(tty)"
print -r -- "$($SUDO -V 2>/dev/null | head -1)"
print -r -- "xcode-select -p: $(xcode-select -p 2>&1) (exit $?)"
[[ -e /Library/Developer/CommandLineTools/usr/bin/git ]] && print -r -- "CLT git: present" || print -r -- "CLT git: absent"
print -r -- "CLT $(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>&1 | grep version)"
if (( $+commands[brew] )); then     # idiom: $+commands[name] is 1 if the command is on PATH
  print -r -- "$(brew --version | head -1)"
  # The reset lives in brew.sh in released versions and in utils/sudo.sh on newer commits.
  print -r -- "files in brew that reset the sudo timestamp:"
  grep -l -- '--reset-timestamp' "$(brew --repository)"/Library/Homebrew/{brew.sh,utils/sudo.sh}(N)   # idiom: (N) glob qualifier drops paths that don't exist
else
  print -r -- "brew: not installed"
fi

print -r -- "== 1. control: no keep-alive. Password prompt 1 of 2."
$SUDO -k
$SUDO -v || exit 1
expect ok   "ticket valid straight after sudo -v" $SUDO -n true
wait_past_expiry
expect fail "ticket expired without a keep-alive" $SUDO -n true

print -r -- "== 2. keep-alive loop running. Password prompt 2 of 2."
$SUDO -v || exit 1
keepalive &                         # idiom: & backgrounds the function in a subshell
keepalive_pid=$!                    # idiom: $! is the PID of the last background job
wait_past_expiry
expect ok   "ticket still valid past expiry (ADR-0008)" $SUDO -n true

print -r -- "== 3. what Homebrew's installer runs under NONINTERACTIVE=1"
expect ok   "installer's access check: sudo -n -l mkdir" $SUDO -n -l mkdir
$SUDO -n -k -l >/dev/null 2>&1      # the installer's detection call; its exit status is not the point
expect ok   "ticket survives the installer's sudo -n -k -l" $SUDO -n true

print -r -- "== 4. a real, read-only brew command"
if (( $+commands[brew] )); then
  HOMEBREW_NO_AUTO_UPDATE=1 brew list >/dev/null 2>&1
  expect fail "ticket gone after brew list" $SUDO -n true
else
  $SUDO --reset-timestamp           # no brew: simulate what its source does
  expect fail "ticket gone after sudo --reset-timestamp" $SUDO -n true
fi
expect fail "keep-alive cannot recover: sudo -n -v" $SUDO -n -v
print -r -- "== done"
```

**Checked in the container.** `zsh -n` passes. Against a stub `sudo` with a 3-second ticket, all seven expectations print `PASS`, including the control, so the probe can fail.

## Result on the Mac

All seven expectations passed on macOS 26.6.2, sudo 1.9.17p2, Homebrew 7.0.2. Shell prompt lines are left out (NFR-3).

```
== facts
macOS 26.6.2, zsh 5.9, tty /dev/ttys002
Sudo version 1.9.17p2
xcode-select -p: /Library/Developer/CommandLineTools (exit 0)
CLT git: present
CLT version: 26.6.0.0.1781586589
Homebrew 7.0.2
reset-timestamp lines in brew's utils/sudo.sh: grep: /opt/homebrew/Library/Homebrew/utils/sudo.sh: No such file or directory
== 1. control: no keep-alive. Password prompt 1 of 2.
Password:
PASS  ticket valid straight after sudo -v (got ok)
waiting 330 s ...
PASS  ticket expired without a keep-alive (got fail)
== 2. keep-alive loop running. Password prompt 2 of 2.
Password:
waiting 330 s ...
PASS  ticket still valid past expiry (ADR-0008) (got ok)
== 3. what Homebrew's installer runs under NONINTERACTIVE=1
PASS  installer's access check: sudo -n -l mkdir (got ok)
PASS  ticket survives the installer's sudo -n -k -l (got ok)
== 4. what brew runs before a cask's sudo
PASS  ticket gone after brew's sudo --reset-timestamp (got fail)
PASS  keep-alive cannot recover: sudo -n -v (got fail)
== done
```

What each step shows:

- **Step 1:** the ticket expires by itself within 330 s, so step 2 could have failed.
- **Step 2:** the keep-alive loop holds the ticket past expiry.
- **Step 3:** the Homebrew installer's sudo calls neither prompt nor drop the ticket.
- **Step 4:** the command `brew` runs drops the ticket, and `sudo -n -v` cannot bring it back.

The failed `grep` in the facts block is the probe looking for `main`'s file. The reset in the installed release was confirmed separately:

```
$ grep -n -- '--reset-timestamp' "$(brew --repository)"/Library/Homebrew/{brew.sh,utils/sudo.sh} 2>/dev/null
/opt/homebrew/Library/Homebrew/brew.sh:652:  "${SUDO}" --reset-timestamp 2>/dev/null || true
```

Not observed: a real `brew` command dropping a live ticket, and a real cask prompting. Both follow from the source plus step 4, and first run for real in sprint 4.
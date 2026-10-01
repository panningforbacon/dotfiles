# Spike S-6: zsh test framework

| | |
| --- | --- |
| **Issue** | #2 |
| **Question** | Which test framework runs fixture tests against zsh functions on macOS 27 with the least friction? |
| **Answer** | **ShellSpec 0.28.1**, vendored and pinned, always invoked as `--shell "/bin/zsh -f"`. Fallback: bats-core. |
| **Decision recorded in** | ADR-0004 |
| **Date** | 2026-09-30 |

## Method

- Maintenance data was taken from each project's git history and tags (shallow clones on 2026-09-30) and from formulae.brew.sh. It was not taken from memory. The GitHub API was rate-limited, so star and issue counts are omitted.
- Each candidate that survived the maintenance and license screens was probed in a Linux container with zsh 5.9, the same zsh version as macOS 27. The probes used the same kind of function the project will test: a pure function, and a function that takes a caller-supplied check function by name.
- The sample test below was then run on the development Mac (see "Result on the Mac").

## Candidates

| | bats-core | ShellSpec | ZUnit | zsh-test-runner (ztr) |
| --- | --- | --- | --- | --- |
| Repository | bats-core/bats-core | shellspec/shellspec | zunit-zsh/zunit | olets/zsh-test-runner |
| Latest release | v1.14.0, 2026-07-21 | 0.28.1, 2021-01-11 | 0.8.2, 2018-01-04 | 2.1.1, 2024-10-26 |
| Latest commit | 2026-09-23 | 2024-09-12 | 2020-06-25 | 2024-10-26 |
| Commits, last 12 months | 167 | 0 | 0 | 0 |
| Where test code runs | bash; zsh only as a subprocess per assertion | the target shell (zsh), in one process | zsh | zsh |
| Homebrew | `bats-core` (homebrew-core) | `shellspec` (homebrew-core) | third-party tap; needs `revolver` on `PATH` | third-party tap |
| Vendorable | yes (pure bash) | yes (pure POSIX sh, ~740 KB runtime files) | yes, plus `revolver` | license forbids it in an MIT repo |
| License | MIT | MIT | MIT | CC BY-NC-SA 4.0 + Hippocratic License 3 |
| Probe result | 2/2 green | 6/6 green on the 0.28.1 tag | not probed: unmaintained | not probed: license |

## zsh support: what the probes showed

**bats-core drives zsh from bash.** Every test body becomes a zsh program inside a bash string:

```bash
zsh_eval() { run /bin/zsh -f -c "source ${LIB:q}; $1"; }   # bash file
@test "stub check fn is honoured" {
  zsh_eval 'stub_missing() { return 1 }; run_check stub_missing'
  [ "$output" = DIFF ]
}
```

This passed, but by accident. `${LIB:q}` is zsh's quote modifier. Bash has no such modifier and reads the same text as a substring expansion, `${var:offset}`: the offset `q` is an unset name, so it evaluates to 0 and bash returns the whole string. With a path containing a space, the test breaks. The two dialects look the same on the page and behave differently, and that cost recurs in every test. Stubs make it worse. Issue 4 needs stub check, apply and verify functions, and issue 3 needs a fixed clock. In bats, every stub has to travel inside a quoted string.

**ShellSpec runs the spec in zsh itself.** The spec, the sourced library and the stubs share one zsh process, so a stub is an ordinary zsh function. The probes confirmed three things:

- **Top-level code runs as zsh, not sh.** Top-level code in an `Include`d library runs under `zsh` emulation, with 1-indexed arrays. `emulate` reports `zsh` both at top level and inside `emulate -L zsh` functions.
- **stdout and stderr are asserted separately.** The matchers are `The output` and `The error`. Issue 3 needs this, because `FAIL` lines go to stderr (§8.5).
- **The 2024 commits are not needed.** The 2021 release (0.28.1, the one Homebrew ships) passes the same probes as the unreleased 2024 master.

**Isolation trap (DEC-18).** `--shell zsh` starts zsh *without* `-f`, so `~/.zshenv` is read. In a probe, a planted `~/.zshenv` leaked a variable into the test and failed it. Only `--shell "/bin/zsh -f"` isolates the suite from the dotfiles this project manages. The sample spec includes a test that fails if `-f` is missing.

## Install path

- **Vendored (chosen).** A pinned copy under `tests/vendor/shellspec/`. `scripts/check` then works straight after a clone, including at the release wipe, before Homebrew exists. The version cannot drift under the suite, and there is no dependency on Homebrew continuing to ship an unmaintained formula.
- **Homebrew (rejected).** It works, but it adds a package that is not in the PRD's package list. That is a change request, not an ADR. It also makes the gate depend on the `brew` stage having run.

## Sample test

A throwaway library and spec, used only for this spike. Output uses `print`, not `lib/log.zsh`, because this is not project code.

`lib/demo.zsh`

```zsh
#!/bin/zsh -f
# Throwaway sample for spike S-6. Not project code: output skips lib/log.zsh.

demo_major() {
  emulate -L zsh
  print -r -- ${1%%.*}    # idiom: longest-suffix removal, ${var%%pattern}
}

# Takes the check function by name, the way converge will (architecture §6).
demo_converge_line() {
  emulate -L zsh
  local subject=$1 check_fn=$2
  if $check_fn; then      # idiom: call-by-name; safe because zsh doesn't word-split
    print -r -- "OK $subject"
  else
    print -u2 -r -- "FAIL $subject"    # idiom: print -u2 writes to fd 2 (stderr)
    return 1
  fi
}
```

`spec/demo_spec.zsh`

```zsh
Include lib/demo.zsh

Describe 'demo_major'
  Parameters
    '27.0.1' 27
    '26.4'   26
    '15'     15
  End

  It "takes the major version from $1"
    When call demo_major "$1"
    The output should eq "$2"
  End
End

Describe 'demo_converge_line'
  It 'prints OK when the stub check passes'
    check_ok() { return 0; }
    When call demo_converge_line Screenshots check_ok
    The status should be success
    The output should eq 'OK Screenshots'
  End

  It 'sends FAIL to stderr and nothing to stdout'
    check_bad() { return 1; }
    When call demo_converge_line Screenshots check_bad
    The status should be failure
    The output should eq ''
    The error should eq 'FAIL Screenshots'
  End
End

Describe 'isolation'
  startup_files_off() { [[ ! -o rcs ]]; }

  It 'runs under zsh -f, so no startup file can leak in'
    When call startup_files_off
    The status should be success
  End
End
```

`.shellspec` (project options file; ShellSpec reads it from the project root)

```
--shell "/bin/zsh -f"
--pattern *_spec.zsh
```

**Falsifiability, checked in the container.**

- Making `check_bad` succeed fails example 5.
- Running with `--shell /bin/zsh` (no `-f`) fails example 6.
- Exit codes: 0 when green, 101 on any failure, so `scripts/check` can rely on them.

## Result on the Mac

== macOS 26.6.2, 5.9, shellspec 0.28.1
== 1. expected: 6 examples, 0 failures, exit 0
Running: /bin/zsh -f [zsh 5.9]
......

Finished in 0.07 seconds (user 0.04 seconds, sys 0.03 seconds)
6 examples, 0 failures

exit=0
== 2. expected: 1 failure (isolation), exit 101: proves -f matters
exit=101

## Risks

- **ShellSpec is dormant.** It has had no release since January 2021 and no commits in the last 12 months. The risk is bounded: it depends only on POSIX `sh` and zsh 5.9, and the vendored copy cannot change under us. If a future macOS breaks it, the fallback is bats-core. Moving to bats-core means rewriting the specs, so the specs should stay thin: fixtures and assertions, with the logic kept in `lib/`.
- **ShellSpec's DSL is a third syntax** (`Describe`/`It`/`When`/`The`). It is still executed as zsh, so any line outside the DSL keywords is ordinary zsh.
- **zsh line coverage is unreliable** according to ShellSpec's own docs. The project does not need coverage.

## Follow-ups (issue 9, `scripts/check`)

- **Vendor the pinned release.** Vendor ShellSpec 0.28.1 under `tests/vendor/shellspec/`, with its `LICENSE`.
- **Add the root options file.** Add `.shellspec` at the repo root with `--shell "/bin/zsh -f"`, `--default-path tests` and `--pattern *_spec.zsh`.
- **Update the layout.** Update `docs/architecture.md` §2 for `tests/vendor/` and the root `.shellspec` file.
- **Rely on the exit code.** Have `scripts/check` treat ShellSpec's exit code as the test verdict.

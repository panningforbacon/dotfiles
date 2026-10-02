# Fixture tests for modules/preflight.zsh (FR-2.1, FR-2.2, NFR-5, CR-1).
# The real lib/log.zsh is loaded, so lines and counters are tested end to
# end; only the clock and the two probes are stubbed. Fixture origins are
# listed in tests/fixtures/README.md.

Describe 'modules/preflight.zsh'
  Include "$SHELLSPEC_PROJECT_ROOT/lib/log.zsh"
  Include "$SHELLSPEC_PROJECT_ROOT/modules/preflight.zsh"

  FIXTURES="$SHELLSPEC_PROJECT_ROOT/tests/fixtures"

  _log_now() { REPLY=10:41:02 }
  # $(<file) reads a file without spawning cat and, like any command
  # substitution, drops the trailing newline, as the real probes do.
  _preflight_probe_arm64()           { REPLY=$(<$FIXTURES/sysctl/$SYSCTL_FIXTURE.txt) }
  _preflight_probe_product_version() { REPLY=$(<$FIXTURES/sw_vers/$SW_VERS_FIXTURE.txt) }

  counts() {
    print -r -- "ok=${LOG_COUNTS[preflight:ok]:-0} changed=${LOG_COUNTS[preflight:changed]:-0}" \
      "would_change=${LOG_COUNTS[preflight:would_change]:-0} failed=${LOG_COUNTS[preflight:failed]:-0}"
  }

  # Defaults describe the development Mac: Apple Silicon on the verified tier.
  setup() {
    unset NO_COLOR CHECK_MODE
    LOG_MODULE=provision; LOG_COUNTS=()
    SYSCTL_FIXTURE=arm64-apple-silicon
    SW_VERS_FIXTURE=27.0
  }
  BeforeEach 'setup'

  Describe '_preflight_macos_major (pure)'
    major_of_fixture() { _preflight_macos_major "$(<$FIXTURES/sw_vers/$1.txt)" && print -r -- $REPLY }

    # Parameters apply to nested groups too, so each table has its own group.
    Describe 'reads the major version from a fixture'
      Parameters
        27.0              27
        27.0.1            27
        26.3.1            26
        15.7.1            15
        28.0              28
        captured-dev-mac  27
      End

      It "reads major $2 from fixture $1"
        When call major_of_fixture $1
        The status should be success
        The stdout should equal $2
      End
    End

    Describe 'rejects what is not a dotted number'
      Parameters
        ''
        'macOS 27.0'
        '27.'
        '.5'
        '27.0 beta'
        '27,0'
        $'27.0\n28.0'
      End

      It "rejects '$1'"
        When call _preflight_macos_major "$1"
        The status should be failure
        The variable REPLY should equal ''
      End
    End
  End

  Describe '_preflight_macos_tier (pure)'
    tier_of() { _preflight_macos_tier $1; print -r -- $REPLY }

    Parameters
      27  verified
      26  tolerated
      15  unsupported
      28  unsupported
      2   unsupported
      270 unsupported
    End

    It "puts major $1 in tier $2"
      When call tier_of $1
      The stdout should equal $2
    End
  End

  Describe '_preflight_is_arm64 (pure)'
    is_arm64_fixture() { _preflight_is_arm64 "$(<$FIXTURES/sysctl/$1.txt)" }

    It 'accepts Apple Silicon'
      When call is_arm64_fixture arm64-apple-silicon
      The status should be success
    End

    It 'accepts the capture from the development Mac'
      When call is_arm64_fixture arm64-captured-dev-mac
      The status should be success
    End

    It 'rejects Intel, where the key is absent and stdout is empty'
      When call is_arm64_fixture arm64-intel
      The status should be failure
    End

    It 'rejects any answer other than 1'
      When call _preflight_is_arm64 0
      The status should be failure
    End
  End

  Describe 'mod_preflight_run'
    It 'macOS 27 on Apple Silicon: two OK lines, returns 0 (FR-2.1, FR-2.2)'
      When call mod_preflight_run
      The status should equal 0
      The line 1 of stdout should equal '10:41:02  ▶        [preflight]       start — 2 items'
      The line 2 of stdout should equal '10:41:02  OK       [preflight]       Apple Silicon: arm64 — supported'
      The line 3 of stdout should equal '10:41:02  OK       [preflight]       macOS: 27.0 — verified tier'
      The line 4 of stdout should equal '10:41:02  ■        [preflight]       finish — 0 changed · 2 ok · 0 failed'
      The stderr should equal ''
      The value "$(counts)" should equal 'ok=2 changed=0 would_change=0 failed=0'
    End

    It 'macOS 26: WARN that the version is unverified, then continues (CR-1)'
      SW_VERS_FIXTURE=26.3.1
      When call mod_preflight_run
      The status should equal 0
      The line 3 of stdout should equal '10:41:02  WARN     [preflight]       macOS: 26.3.1 is in the tolerated tier — unverified, continuing'
      The stderr should equal ''
      The value "$(counts)" should equal 'ok=1 changed=0 would_change=0 failed=0'
    End

    It 'macOS 15: FAIL with the update remedy, returns 2 (FR-2.2)'
      SW_VERS_FIXTURE=15.7.1
      When call mod_preflight_run
      The status should equal 2
      The stderr should equal '10:41:02  FAIL     [preflight]       macOS: expected 26 or 27, found 15.7.1 — update macOS in System Settings, then re-run'
      The stdout should include 'Apple Silicon: arm64 — supported'
      The stdout should include 'finish — 0 changed · 1 ok · 1 failed'
    End

    It 'macOS 28: FAIL without the update remedy, returns 2 (FR-2.2)'
      SW_VERS_FIXTURE=28.0
      When call mod_preflight_run
      The status should equal 2
      The stderr should equal '10:41:02  FAIL     [preflight]       macOS: expected 26 or 27, found 28.0 — this macOS is newer than the project supports; it has to be verified first (see the README)'
      The stdout should include 'finish — 0 changed · 1 ok · 1 failed'
    End

    It 'unreadable sw_vers output: FAIL naming what was read, returns 2'
      _preflight_probe_product_version() { REPLY='' }
      When call mod_preflight_run
      The status should equal 2
      The stderr should include "macOS: could not read a version from sw_vers (got '') — run /usr/bin/sw_vers -productVersion"
      The stdout should include 'finish — 0 changed · 1 ok · 1 failed'
    End

    It 'Intel: FAIL naming the hardware, returns 2 (FR-2.1)'
      SYSCTL_FIXTURE=arm64-intel
      When call mod_preflight_run
      The status should equal 2
      The stderr should equal '10:41:02  FAIL     [preflight]       Apple Silicon: expected arm64, found Intel — this project supports Apple Silicon only'
      The stdout should include 'macOS: 27.0 — verified tier'
    End

    It 'Intel on macOS 15: reports both reasons in one run'
      SYSCTL_FIXTURE=arm64-intel; SW_VERS_FIXTURE=15.7.1
      When call mod_preflight_run
      The status should equal 2
      The line 1 of stderr should include 'Apple Silicon: expected arm64, found Intel'
      The line 2 of stderr should include 'macOS: expected 26 or 27, found 15.7.1'
      The stdout should include 'finish — 0 changed · 0 ok · 2 failed'
    End

    Describe 'in check mode: a refusal stays a FAIL, never a DIFF (architecture §6)'
      It 'Intel still fails and returns 2'
        CHECK_MODE=1; SYSCTL_FIXTURE=arm64-intel
        When call mod_preflight_run
        The status should equal 2
        The stderr should include 'FAIL     [preflight]       Apple Silicon: expected arm64, found Intel'
        The stdout should not include 'DIFF'
      End

      It 'an unsupported macOS still fails and returns 2'
        CHECK_MODE=1; SW_VERS_FIXTURE=15.7.1
        When call mod_preflight_run
        The status should equal 2
        The stderr should include 'FAIL     [preflight]       macOS: expected 26 or 27, found 15.7.1'
        The stdout should not include 'DIFF'
      End

      It 'a supported Mac passes exactly as in a normal run'
        CHECK_MODE=1
        When call mod_preflight_run
        The status should equal 0
        The stdout should include 'finish — 0 changed · 2 ok · 0 failed'
      End
    End

    Describe 'changes nothing (FR-2)'
      # With an empty PATH and both probes stubbed, any command the stage
      # tried to run, other than a builtin, would fail and show up in stderr.
      run_with_empty_path() { ( path=(); mod_preflight_run ) }

      It 'runs no command besides its two probes'
        When call run_with_empty_path
        The status should equal 0
        The stdout should include 'finish — 0 changed · 2 ok · 0 failed'
        The stderr should equal ''
      End
    End
  End

  Describe 'conventions'
    It 'uses the -f shebang (DEC-18)'
      The line 1 of contents of file "$SHELLSPEC_PROJECT_ROOT/modules/preflight.zsh" should equal '#!/bin/zsh -f'
    End
  End
End

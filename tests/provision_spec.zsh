# Fixture tests for bin/provision (docs/architecture.md §3, §4; FR-15.3, FR-16.1).
# The real script and the real lib/ are copied into a temporary checkout whose
# modules/ holds stubs, so stage order, stopping, the summary and the exit
# code are tested end to end without touching the machine.

Describe 'bin/provision'
  TREE="$SHELLSPEC_TMPBASE/checkout"

  # Each stub freezes the clock, reports the modes it sees, optionally logs
  # one line or reads an unset parameter, and returns the status the test set.
  write_stub() {
    print -r -- "
_log_now() { REPLY=10:41:02 }
mod_$1_run() {
  emulate -L zsh
  log_start $1 1
  log NOTE '' \"check=\$CHECK_MODE upgrade=\$UPGRADE_MODE\"
  [[ -n \${STUB_${1}_LOG:-} ]] && log \$STUB_${1}_LOG item 'stub line'
  if [[ -n \${STUB_${1}_CRASH:-} ]]; then
    setopt NO_UNSET
    : \$never_set
  fi
  log_finish
  return \${STUB_${1}_RC:-0}
}" > $TREE/modules/$1.zsh
  }

  setup() {
    rm -rf $TREE
    mkdir -p $TREE/bin $TREE/modules
    cp $SHELLSPEC_PROJECT_ROOT/bin/provision $TREE/bin/provision
    cp -R $SHELLSPEC_PROJECT_ROOT/lib $TREE/lib
    write_stub preflight
    write_stub defaults
    unset NO_COLOR CHECK_MODE UPGRADE_MODE
    unset STUB_preflight_LOG STUB_preflight_RC STUB_preflight_CRASH
    unset STUB_defaults_LOG STUB_defaults_RC
  }
  BeforeEach 'setup'

  provision() { $TREE/bin/provision "$@" }

  Describe 'options'
    It '--help prints usage and exits 0 without running a stage'
      When run provision --help
      The status should equal 0
      The line 1 of stdout should equal 'usage: bin/provision [--check] [--upgrade] [--help]'
      The stdout should include 'Affects runtimes only'
      The stdout should not include '[preflight]'
    End

    It 'an unknown option prints one FAIL and usage on stderr, and exits 64'
      When run provision --nope
      The status should equal 64
      The stdout should equal ''
      The line 1 of stderr should end with 'FAIL     [provision]       --nope: unknown option — see the usage below'
      The line 2 of stderr should equal 'usage: bin/provision [--check] [--upgrade] [--help]'
    End

    It 'a bare word is a usage error too'
      When run provision check
      The status should equal 64
      The stderr should include 'check: unknown option'
    End

    It 'no option: check and upgrade modes are off in every stage'
      When run provision
      The status should equal 0
      The line 2 of stdout should equal '10:41:02  NOTE     [preflight]       check=0 upgrade=0'
      The line 5 of stdout should equal '10:41:02  NOTE     [defaults]        check=0 upgrade=0'
    End

    It '--check and --upgrade reach every stage (FR-16.1, CR-11)'
      When run provision --check --upgrade
      The status should equal 0
      The line 2 of stdout should equal '10:41:02  NOTE     [preflight]       check=1 upgrade=1'
      The line 5 of stdout should equal '10:41:02  NOTE     [defaults]        check=1 upgrade=1'
    End
  End

  Describe 'stages and summary'
    It 'runs stages in array order and totals the counts (FR-15.3)'
      export STUB_preflight_LOG=OK STUB_defaults_LOG=CHANGED
      When run provision
      The status should equal 0
      The line 1 of stdout should equal '10:41:02  ▶        [preflight]       start — 1 items'
      The line 5 of stdout should equal '10:41:02  ▶        [defaults]        start — 1 items'
      The line 9 of stdout should equal '10:41:02  NOTE     [summary]         run: 1 changed · 1 ok · 0 failed'
      The lines of stdout should equal 9
      The stderr should equal ''
    End

    It 'check mode: the summary reports the would-change count (FR-16.1)'
      export STUB_preflight_LOG=OK STUB_defaults_LOG=DIFF
      When run provision --check
      The status should equal 0
      The line 9 of stdout should equal '10:41:02  NOTE     [summary]         check: 1 would change · 1 ok · 0 failed'
    End

    It 'a stage returning 1 stops the run; the summary still prints; exit 1'
      export STUB_preflight_LOG=FAIL STUB_preflight_RC=1
      When run provision
      The status should equal 1
      The stdout should not include '[defaults]'
      The line 4 of stdout should equal '10:41:02  NOTE     [summary]         run: 0 changed · 0 ok · 1 failed'
      The line 5 of stdout should equal '10:41:02  NOTE     [summary]         stopped at preflight — fix what it reported, then re-run'
      The stderr should equal '10:41:02  FAIL     [preflight]       item: stub line'
    End

    It 'a stage returning 2 stops the run; the summary still prints; exit 2'
      export STUB_preflight_RC=2
      When run provision
      The status should equal 2
      The stdout should not include '[defaults]'
      The line 4 of stdout should equal '10:41:02  NOTE     [summary]         run: 0 changed · 0 ok · 0 failed'
      The line 5 of stdout should equal '10:41:02  NOTE     [summary]         stopped at preflight — fix what it reported, then re-run'
      The stderr should equal ''
    End

    It 'a FAIL in a stage that returns 0 does not stop the run, but exits 1 (FR-15.1)'
      export STUB_preflight_LOG=FAIL
      When run provision
      The status should equal 1
      The stdout should include '[defaults]'
      The stdout should include 'run: 0 changed · 0 ok · 1 failed'
      The stdout should not include 'stopped at'
      The stderr should include 'FAIL     [preflight]'
    End
  End

  Describe 'failures that would otherwise be silent'
    It 'a stage returning 1 without a FAIL line gets one from the runner'
      export STUB_preflight_RC=1
      When run provision
      The status should equal 1
      The stderr should equal '10:41:02  FAIL     [provision]       preflight: mod_preflight_run returned 1 without a FAIL line — this is a bug in modules/preflight.zsh'
      The stdout should include 'run: 0 changed · 0 ok · 1 failed'
    End

    It 'a stage returning anything but 0, 1 or 2 is a FAIL and exits 1'
      export STUB_preflight_RC=7
      When run provision
      The status should equal 1
      The stderr should include 'mod_preflight_run returned 7, but a module returns 0, 1 or 2'
      The stdout should include 'stopped at preflight'
    End

    It 'a missing module fails before any stage runs'
      rm $TREE/modules/defaults.zsh
      When run provision
      The status should equal 1
      The stdout should not include '▶'
      The stderr should include 'defaults: modules/defaults.zsh is missing'
      The stdout should include 'run: 0 changed · 0 ok · 1 failed'
    End

    It 'a module without its run function fails before any stage runs'
      print -r -- '_log_now() { REPLY=10:41:02 }' > $TREE/modules/defaults.zsh
      When run provision
      The status should equal 1
      The stdout should not include '▶'
      The stderr should include 'does not define mod_defaults_run'
    End

    It 'a zsh error inside a stage still ends with a FAIL, the summary and exit 1'
      export STUB_preflight_CRASH=1
      When run provision
      The status should equal 1
      The stderr should include 'never_set: parameter not set'
      The stderr should include 'FAIL     [provision]       provision: stopped by the zsh error above'
      The stdout should include 'run: 0 changed · 0 ok · 1 failed'
      The stdout should not include '[defaults]'
    End
  End

  Describe 'conventions'
    It 'uses the -f shebang (DEC-18)'
      The line 1 of contents of file "$SHELLSPEC_PROJECT_ROOT/bin/provision" should equal '#!/bin/zsh -f'
    End

    It 'runs the checkout it lives in, whatever DOTFILES_DIR says (CR-6)'
      export DOTFILES_DIR=/nonexistent
      When run provision --help
      The status should equal 0
      The stdout should include "declared in ${TREE:A}."
    End
  End
End
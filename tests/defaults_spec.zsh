# Fixture tests for modules/defaults.zsh (FR-10.4, FR-14, FR-16.1, CR-18).
# The real lib/log.zsh and lib/converge.zsh are loaded and the stage runs
# against a temporary HOME, so real folders are created and read back without
# touching the machine. Only the clock is stubbed.

Describe 'modules/defaults.zsh'
  Include "$SHELLSPEC_PROJECT_ROOT/lib/log.zsh"
  Include "$SHELLSPEC_PROJECT_ROOT/lib/converge.zsh"
  Include "$SHELLSPEC_PROJECT_ROOT/modules/defaults.zsh"

  _log_now() { REPLY=10:41:02 }

  FAKE_HOME="$SHELLSPEC_TMPBASE/home"
  SHOTS="$FAKE_HOME/Desktop/Screenshots"

  setup() {
    unset NO_COLOR CHECK_MODE
    LOG_MODULE=provision; LOG_COUNTS=()
    rm -rf $FAKE_HOME
    mkdir -p $FAKE_HOME/Desktop
    HOME=$FAKE_HOME
  }
  BeforeEach 'setup'

  kind_of_shots() {
    if   [[ -L $SHOTS ]]; then print link
    elif [[ -d $SHOTS ]]; then print folder
    elif [[ -f $SHOTS ]]; then print file
    else                       print missing
    fi
  }

  Describe 'the screenshot folder (FR-10.4)'
    It 'missing: creates it and prints one CHANGED line (CR-18)'
      When call mod_defaults_run
      The status should equal 0
      The line 1 of stdout should equal '10:41:02  ▶        [defaults]        start — 1 items'
      The line 2 of stdout should equal '10:41:02  CHANGED  [defaults]        Screenshots folder: created — verified'
      The line 3 of stdout should equal '10:41:02  ■        [defaults]        finish — 1 changed · 0 ok · 0 failed'
      The lines of stdout should equal 3
      The stderr should equal ''
      The value "$(kind_of_shots)" should equal folder
    End

    It 'existing: prints one OK line (FR-14.1)'
      mkdir $SHOTS
      When call mod_defaults_run
      The status should equal 0
      The line 2 of stdout should equal '10:41:02  OK       [defaults]        Screenshots folder: already present — skipping'
      The line 3 of stdout should equal '10:41:02  ■        [defaults]        finish — 0 changed · 1 ok · 0 failed'
      The lines of stdout should equal 3
      The stderr should equal ''
    End

    It 'a second consecutive run changes nothing (M3)'
      run_twice() { mod_defaults_run > /dev/null; mod_defaults_run }
      When call run_twice
      The status should equal 0
      The line 2 of stdout should equal '10:41:02  OK       [defaults]        Screenshots folder: already present — skipping'
      The line 3 of stdout should equal '10:41:02  ■        [defaults]        finish — 0 changed · 1 ok · 0 failed'
    End

    It 'a regular file at the path: FAIL names the path and the remedy; the file is untouched (FR-14.2, FR-15.1)'
      print -r -- 'keep me' > $SHOTS
      When call mod_defaults_run
      The status should equal 1
      The stderr should equal '10:41:02  FAIL     [defaults]        Screenshots folder: found something that is not a folder, left untouched — move aside whatever is at ~/Desktop/Screenshots, then re-run'
      The line 2 of stdout should equal '10:41:02  ■        [defaults]        finish — 0 changed · 0 ok · 1 failed'
      The lines of stdout should equal 2
      The value "$(kind_of_shots)" should equal file
      The contents of file "$SHOTS" should equal 'keep me'
    End

    It 'a symlink to a folder counts as present and stays a symlink (FR-14.2)'
      mkdir $FAKE_HOME/elsewhere
      ln -s $FAKE_HOME/elsewhere $SHOTS
      When call mod_defaults_run
      The status should equal 0
      The line 2 of stdout should end with 'Screenshots folder: already present — skipping'
      The value "$(kind_of_shots)" should equal link
    End

    It 'a dangling symlink is not a folder: FAIL, and the link is untouched'
      ln -s $FAKE_HOME/nowhere $SHOTS
      When call mod_defaults_run
      The status should equal 1
      The stderr should include 'found something that is not a folder, left untouched'
      The stdout should include '0 changed · 0 ok · 1 failed'
      The value "$(kind_of_shots)" should equal link
    End

    It "a failing mkdir: its own error becomes the one FAIL line, never raw stderr (FR-15.4)"
      # A file where ~/Desktop should be makes mkdir fail on every system.
      rmdir $FAKE_HOME/Desktop; : > $FAKE_HOME/Desktop
      When call mod_defaults_run
      The status should equal 1
      The lines of stderr should equal 1
      The stderr should start with '10:41:02  FAIL     [defaults]        Screenshots folder: mkdir'
      The stderr should end with '— move aside whatever is at ~/Desktop/Screenshots, then re-run'
      The stdout should include '0 changed · 0 ok · 1 failed'
    End
  End

  Describe 'in check mode (FR-16.1)'
    It 'missing: prints one DIFF line and creates nothing'
      CHECK_MODE=1
      When call mod_defaults_run
      The status should equal 0
      The line 2 of stdout should equal '10:41:02  DIFF     [defaults]        Screenshots folder: missing — would change'
      The lines of stdout should equal 3
      The stderr should equal ''
      The value "$(kind_of_shots)" should equal missing
      The value "${LOG_COUNTS[defaults:would_change]}" should equal 1
    End

    It 'existing: prints OK, exactly as in a normal run'
      CHECK_MODE=1
      mkdir $SHOTS
      When call mod_defaults_run
      The status should equal 0
      The line 2 of stdout should end with 'Screenshots folder: already present — skipping'
    End

    # Known gap, accepted for issue 7: check has no "blocked" outcome, so an
    # obstruction reads as DIFF although a real run would FAIL. The follow-up
    # ADR changes this expectation.
    It 'a file at the path: reports DIFF and leaves the file untouched'
      CHECK_MODE=1
      print -r -- 'keep me' > $SHOTS
      When call mod_defaults_run
      The status should equal 0
      The line 2 of stdout should equal '10:41:02  DIFF     [defaults]        Screenshots folder: not a folder — would change'
      The contents of file "$SHOTS" should equal 'keep me'
    End
  End

  Describe 'conventions'
    It 'uses the -f shebang (DEC-18)'
      The line 1 of contents of file "$SHELLSPEC_PROJECT_ROOT/modules/defaults.zsh" should equal '#!/bin/zsh -f'
    End
  End
End
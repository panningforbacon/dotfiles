# Fixture tests for lib/converge.zsh (docs/architecture.md §6, PRD §8.5).
# The real lib/log.zsh is loaded, so line format and counters are tested end
# to end; only the clock and the three item functions are stubbed.

Describe 'lib/converge.zsh'
  Include "$SHELLSPEC_PROJECT_ROOT/lib/log.zsh"
  Include "$SHELLSPEC_PROJECT_ROOT/lib/converge.zsh"

  _log_now() { REPLY=10:41:02 }

  # converge runs each function in a subshell, so an array would lose the
  # record of calls; a file survives the subshell.
  CALLS="$SHELLSPEC_TMPBASE/converge-calls"

  stub_check()  { print -r -- "check ${(j:|:)@}"  >> $CALLS; print -r -- "$CHECK_SAYS";  return $CHECK_RC }
  stub_apply()  { print -r -- "apply ${(j:|:)@}"  >> $CALLS; print -r -- "$APPLY_SAYS";  return $APPLY_RC }
  stub_verify() { print -r -- "verify ${(j:|:)@}" >> $CALLS; print -r -- "$VERIFY_SAYS"; return $VERIFY_RC }

  item() {
    converge 'Screenshots folder' present 'move the file aside, then re-run' \
      stub_check stub_apply stub_verify /tmp/shots
  }

  counts() {
    print -r -- "ok=${LOG_COUNTS[dotfiles:ok]:-0} changed=${LOG_COUNTS[dotfiles:changed]:-0}" \
      "would_change=${LOG_COUNTS[dotfiles:would_change]:-0} failed=${LOG_COUNTS[dotfiles:failed]:-0}"
  }

  # Defaults describe a missing item whose apply and verify both succeed.
  setup() {
    unset NO_COLOR CHECK_MODE
    LOG_MODULE=dotfiles; LOG_COUNTS=()
    : > $CALLS
    CHECK_SAYS=missing;  CHECK_RC=1
    APPLY_SAYS=created;  APPLY_RC=0
    VERIFY_SAYS=present; VERIFY_RC=0
  }
  BeforeEach 'setup'

  Describe 'the five outcomes'
    It 'OK: already in the desired state, apply never called (FR-14.1)'
      CHECK_SAYS=present; CHECK_RC=0
      When call item
      The status should be success
      The stdout should equal '10:41:02  OK       [dotfiles]        Screenshots folder: already present — skipping'
      The stderr should equal ''
      The contents of file "$CALLS" should equal 'check /tmp/shots'
      The value "$(counts)" should equal 'ok=1 changed=0 would_change=0 failed=0'
    End

    It 'DIFF: differs in check mode, apply never called (FR-16.1)'
      CHECK_MODE=1
      When call item
      The status should be success
      The stdout should equal '10:41:02  DIFF     [dotfiles]        Screenshots folder: missing — would change'
      The stderr should equal ''
      The contents of file "$CALLS" should equal 'check /tmp/shots'
      The value "$(counts)" should equal 'ok=0 changed=0 would_change=1 failed=0'
    End

    It 'CHANGED: printed only after the read-back confirms (CR-18)'
      When call item
      The status should be success
      The stdout should equal '10:41:02  CHANGED  [dotfiles]        Screenshots folder: created — verified'
      The stderr should equal ''
      The contents of file "$CALLS" should equal "check /tmp/shots
apply /tmp/shots
verify /tmp/shots"
      The value "$(counts)" should equal 'ok=0 changed=1 would_change=0 failed=0'
    End

    It 'FAIL on apply: names what failed and the remedy; verify never called (FR-15.1)'
      stub_apply() { print -r -- "apply ${(j:|:)@}" >> $CALLS; print -u2 -r -- 'mkdir: /tmp/shots: File exists'; return 1 }
      When call item
      The status should be failure
      The stdout should equal ''
      The stderr should equal '10:41:02  FAIL     [dotfiles]        Screenshots folder: mkdir: /tmp/shots: File exists — move the file aside, then re-run'
      The contents of file "$CALLS" should equal "check /tmp/shots
apply /tmp/shots"
      The value "$(counts)" should equal 'ok=0 changed=0 would_change=0 failed=1'
    End

    It 'FAIL on verify: expected and found values, never CHANGED (FR-15.1, FR-10.2)'
      VERIFY_SAYS=file; VERIFY_RC=1
      When call item
      The status should be failure
      The stdout should equal ''
      The stderr should equal '10:41:02  FAIL     [dotfiles]        Screenshots folder: expected present, found file — move the file aside, then re-run'
      The value "$(counts)" should equal 'ok=0 changed=0 would_change=0 failed=1'
    End
  End

  Describe 'check mode'
    It 'still reports OK when nothing differs'
      CHECK_MODE=1; CHECK_SAYS=present; CHECK_RC=0
      When call item
      The stdout should equal '10:41:02  OK       [dotfiles]        Screenshots folder: already present — skipping'
      The contents of file "$CALLS" should equal 'check /tmp/shots'
    End

    It 'is off when CHECK_MODE is 0'
      CHECK_MODE=0
      When call item
      The stdout should include 'CHANGED'
    End

    It 'treats any other non-empty value as on, so a typo changes nothing'
      CHECK_MODE=yes
      When call item
      The stdout should include 'DIFF'
      The contents of file "$CALLS" should equal 'check /tmp/shots'
    End
  End

  Describe 'captured output'
    It 'joins multi-line output into one line'
      APPLY_SAYS=$'line one\nline two'; APPLY_RC=1
      When call item
      The status should be failure
      The stdout should equal ''
      The stderr should equal '10:41:02  FAIL     [dotfiles]        Screenshots folder: line one; line two — move the file aside, then re-run'
    End

    It 'names the apply function and its exit code when it printed nothing'
      stub_apply() { return 3 }
      When call item
      The status should be failure
      The stdout should equal ''
      The stderr should equal '10:41:02  FAIL     [dotfiles]        Screenshots folder: stub_apply exited 3 — move the file aside, then re-run'
    End

    It 'passes every extra argument, unsplit, to all three functions'
      multi_arg_item() { converge s d r stub_check stub_apply stub_verify 'a b' c }
      When call multi_arg_item
      The stdout should equal '10:41:02  CHANGED  [dotfiles]        s: created — verified'
      The contents of file "$CALLS" should equal "check a b|c
apply a b|c
verify a b|c"
    End
  End

  Describe 'misuse'
    It 'turns a wrong argument count into a FAIL'
      short_call() { converge s d r stub_check stub_apply }
      When call short_call
      The status should be failure
      The stderr should equal '10:41:02  FAIL     [dotfiles]        converge: expected at least 6 arguments, got 5 — call converge subject desired remedy check_fn apply_fn verify_fn [args...]'
      The value "$(counts)" should equal 'ok=0 changed=0 would_change=0 failed=1'
    End

    It 'turns an undefined function into a FAIL before anything runs, even in check mode'
      CHECK_MODE=1
      typo_call() { converge s d r stub_check stub_aply stub_verify }
      When call typo_call
      The status should be failure
      The stderr should equal "10:41:02  FAIL     [dotfiles]        converge: 'stub_aply' is not a function, for 's' — call converge subject desired remedy check_fn apply_fn verify_fn [args...]"
      The contents of file "$CALLS" should equal ''
    End
  End
End
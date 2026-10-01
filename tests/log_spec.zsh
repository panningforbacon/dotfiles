# Fixture tests for lib/log.zsh (ADR-0009, docs/architecture.md §7, PRD §8.5).
# Expected lines are inline rather than in tests/fixtures/: colored lines hold
# escape bytes, which would be invisible in a fixture file's diff.

Describe 'lib/log.zsh'
  Include "$SHELLSPEC_PROJECT_ROOT/lib/log.zsh"

  # Fixed clock, so every line can be compared exactly.
  _log_now() { REPLY=10:41:02 }
  # ShellSpec captures output into files, so streams are never terminals and
  # color is off unless a test overrides this.
  setup() { unset NO_COLOR; LOG_MODULE=dotfiles; LOG_COUNTS=() }
  BeforeEach 'setup'

  ESC=$'\e'

  Describe 'log, one line per status'
    Parameters
      OK      git     'already installed — skipping' '10:41:02  OK       [dotfiles]        git: already installed — skipping'
      CHANGED neovim  'installed — verified'         '10:41:02  CHANGED  [dotfiles]        neovim: installed — verified'
      DIFF    folder  'missing — would change'       '10:41:02  DIFF     [dotfiles]        folder: missing — would change'
      WARN    .zshrc  'existing file backed up'      '10:41:02  WARN     [dotfiles]        .zshrc: existing file backed up'
      ACTION  GitHub  'sign in, then press Enter.'   '10:41:02  ACTION   [dotfiles]        GitHub: sign in, then press Enter.'
      NOTE    notes   'see the Brewfile'             '10:41:02  NOTE     [dotfiles]        notes: see the Brewfile'
    End

    It "prints $1 to stdout and nothing to stderr"
      When call log "$1" "$2" "$3"
      The status should be success
      The stdout should equal "$4"
      The stderr should equal ''
    End
  End

  It 'prints FAIL to stderr and nothing to stdout'
    When call log FAIL neovim 'expected installed, found missing — run brew doctor'
    The status should be success
    The stdout should equal ''
    The stderr should equal '10:41:02  FAIL     [dotfiles]        neovim: expected installed, found missing — run brew doctor'
  End

  It 'prints the message alone when the subject is empty (compact settings form)'
    LOG_MODULE=defaults.dock
    When call log OK '' 'Icon size ....  48 → 48   no change'
    The stdout should equal '10:41:02  OK       [defaults.dock]   Icon size ....  48 → 48   no change'
  End

  It 'never truncates a module name longer than its column'
    LOG_MODULE=defaults.activity-monitor
    When call log NOTE x y
    The stdout should equal '10:41:02  NOTE     [defaults.activity-monitor]  x: y'
  End

  It 'prints % and backslashes literally'
    When call log NOTE path 'C:\new %s'
    The stdout should equal '10:41:02  NOTE     [dotfiles]        path: C:\new %s'
  End

  Describe 'misuse'
    It 'turns an unknown status into a FAIL naming it'
      When call log OKK git 'whatever'
      The status should be failure
      The stdout should equal ''
      The stderr should equal "10:41:02  FAIL     [dotfiles]        log: unknown status 'OKK' for 'git' — use one of ACTION, CHANGED, DIFF, FAIL, NOTE, OK, WARN"
    End

    It 'turns a wrong argument count into a FAIL'
      When call log OK git
      The status should be failure
      The stderr should equal '10:41:02  FAIL     [dotfiles]        log: expected 3 arguments, got 2 — call log STATUS subject message'
    End

    It 'rejects a non-numeric item count in log_start'
      When call log_start brew many
      The status should be failure
      The stderr should equal "10:41:02  FAIL     [dotfiles]        log: log_start got 'brew many' — call log_start <module> <item-count>"
    End

    # A misuse must make the run exit 1 (FR-15.1), so it has to reach the failed count.
    module_with_typo() {
      log_start dotfiles 1
      log OKK git whatever 2>/dev/null
      log_finish
    }
    It 'counts a misuse as failed'
      When call module_with_typo
      The line 2 of stdout should equal '10:41:02  ■        [dotfiles]        finish — 0 changed · 0 ok · 1 failed'
    End
  End

  Describe 'headers'
    It 'prints the start header and sets the module'
      When call log_start defaults.dock 7
      The stdout should equal '10:41:02  ▶        [defaults.dock]   start — 7 items'
      The variable LOG_MODULE should equal 'defaults.dock'
    End

    module_run() {
      log_start dotfiles 6
      log OK a 'already linked — skipping'
      log OK b 'already linked — skipping'
      log CHANGED c 'linked — verified'
      log FAIL d 'link failed — remove d, then re-run' 2>/dev/null
      log DIFF e 'missing — would change'
      log WARN f 'backed up'
      log_finish
    }
    It 'prints the finish header with this module'"'"'s counts'
      When call module_run
      The line 1 of stdout should equal '10:41:02  ▶        [dotfiles]        start — 6 items'
      The line 7 of stdout should equal '10:41:02  ■        [dotfiles]        finish — 1 changed · 2 ok · 1 failed'
    End

    It 'keeps each module'"'"'s counts, including would-change, for the run summary'
      two_modules() {
        log_start one 1; log CHANGED a 'done — verified'; log_finish
        log_start two 2; log OK b 'already set — skipping'; log DIFF c 'unset — would change'; log_finish
      }
      When call two_modules
      The stdout should include 'finish — 1 changed · 0 ok · 0 failed'
      The stdout should include 'finish — 0 changed · 1 ok · 0 failed'
      The value "${LOG_COUNTS[one:changed]}" should equal 1
      The value "${LOG_COUNTS[two:would_change]}" should equal 1
      The value "${LOG_COUNTS[two:failed]}" should equal 0
    End
  End

  Describe 'color'
    Describe 'when the stream counts as a terminal'
      _log_color_on() { [[ -z ${NO_COLOR:-} ]] }

      Parameters
        OK      '2'
        CHANGED '32'
        DIFF    '36'
        WARN    '33'
        ACTION  '1;35'
      End
      It "wraps a $1 line in SGR $2"
        When call log "$1" s m
        The stdout should equal "${ESC}[$2m10:41:02  ${(r:7:)1}  [dotfiles]        s: m${ESC}[0m"
      End

      It 'colors FAIL red on stderr'
        When call log FAIL s m
        The stderr should equal "${ESC}[31m10:41:02  FAIL     [dotfiles]        s: m${ESC}[0m"
      End

      It 'leaves NOTE uncolored'
        When call log NOTE s m
        The stdout should equal '10:41:02  NOTE     [dotfiles]        s: m'
      End

      It 'prints headers bold'
        When call log_start dotfiles 1
        The stdout should equal "${ESC}[1m10:41:02  ▶        [dotfiles]        start — 1 items${ESC}[0m"
      End

      It 'turns color off when NO_COLOR is set'
        export NO_COLOR=1
        When call log OK s m
        The stdout should equal '10:41:02  OK       [dotfiles]        s: m'
      End
    End

    It 'is off when the stream is not a terminal'
      When call log CHANGED s m
      The stdout should equal '10:41:02  CHANGED  [dotfiles]        s: m'
    End

    # The tests above stub the terminal check. These run the real one inside a
    # pseudo-terminal (zsh/zpty), so stdout really is a TTY.
    Describe 'in a real terminal'
      pty_line() {
        zmodload zsh/zpty
        local out lib="$SHELLSPEC_PROJECT_ROOT/lib/log.zsh"
        zpty logpty "NO_COLOR=${(q)1} /bin/zsh -f -c 'source ${(q)lib}; log OK git done'"
        zpty -r logpty out '*done*'
        zpty -d logpty
        print -r -- "$out"
      }

      It 'colors when NO_COLOR is empty'
        When call pty_line ''
        The stdout should start with "${ESC}[2m"
      End

      It 'does not color when NO_COLOR is set'
        When call pty_line 1
        The stdout should not include "${ESC}["
        The stdout should include 'OK       [provision]       git: done'
      End
    End
  End
End
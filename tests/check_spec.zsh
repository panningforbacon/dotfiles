# Fixture tests for scripts/check (CR-7, ADR-0004). The gate runs against a
# throwaway tree, never this repository, and ShellSpec itself is a stub
# there: running the real suite from inside the suite would never end.

Include scripts/check

Describe 'scripts/check'
  TREE="$SHELLSPEC_TMPBASE/check"

  # write <path-in-tree> <content>
  write() {
    mkdir -p $TREE/${1:h}    # :h is the directory part, like dirname
    print -r -- $2 > $TREE/$1
  }

  # write_runner <exit-code>: a stand-in for the vendored ShellSpec.
  write_runner() {
    write tests/vendor/shellspec/shellspec "echo 'runner ran in' \"\$PWD\"; exit $1"
  }

  setup() {
    rm -rf $TREE
    unset NO_COLOR
    write bootstrap.zsh       'print loader'
    write bin/provision       'print provision'
    write lib/log.zsh         'log() { print -r -- "$@" }'
    write modules/sub/deep.zsh 'print deep'
    write scripts/check       'print gate'
    write_runner 0
  }
  BeforeEach 'setup'

  selected() {
    check_syntax_files $TREE
    print -rl -- ${reply#$TREE/}
  }

  Describe 'file selection'
    It 'takes bootstrap.zsh and everything in bin, lib, modules and scripts'
      When call selected
      The line 1 of output should equal 'bootstrap.zsh'
      The line 2 of output should equal 'bin/provision'
      The line 3 of output should equal 'lib/log.zsh'
      The line 4 of output should equal 'modules/sub/deep.zsh'
      The line 5 of output should equal 'scripts/check'
      The lines of output should equal 5
    End

    It 'skips .gitkeep, tests, the vendored runner and docs'
      write scripts/.gitkeep ''
      write tests/a_spec.zsh 'Describe x; End'
      write docs/notes.zsh   'if then'
      When call selected
      The lines of output should equal 5
      The output should not include '.gitkeep'
      The output should not include 'tests/'
      The output should not include 'docs/'
    End

    It 'takes zsh startup files and *.zsh under home, at any depth'
      write home/.zshrc                  'print rc'
      write home/.zprofile               'print profile'
      write home/.config/zsh/aliases.zsh 'print aliases'
      When call selected
      The lines of output should equal 8
      The output should include 'home/.zshrc'
      The output should include 'home/.zprofile'
      The output should include 'home/.config/zsh/aliases.zsh'
    End

    It 'skips the files under home that are not zsh'
      write home/.zsh_plugins.txt        'not zsh ('
      write home/.config/starship.toml   '[character]'
      write home/.config/nvim/init.lua   'if then'
      When call selected
      The lines of output should equal 5
    End
  End

  Describe 'syntax step'
    It 'prints one OK per file when every file parses'
      When call check_syntax $TREE
      The status should equal 0
      The lines of stdout should equal 5
      The line 1 of stdout should end with '  OK       [provision]       bootstrap.zsh: zsh -n passed'
      The stderr should equal ''
    End

    It 'names the failing file and line, and still checks the others'
      write lib/broken.zsh $'print fine\nif then'
      When call check_syntax $TREE
      The status should equal 1
      The lines of stdout should equal 5
      The lines of stderr should equal 1
      The stderr should include '  FAIL     [provision]       lib/broken.zsh: zsh -n failed (lib/broken.zsh:3: parse error'
      The stderr should end with ' — fix the syntax error, then run scripts/check again'
    End

    It 'fails a broken dotfile under home'
      write home/.zshrc 'for x in; do'
      When call check_syntax $TREE
      The status should equal 1
      The stdout should include 'bootstrap.zsh'
      The stderr should include 'home/.zshrc: zsh -n failed'
    End

    It 'does not run the files it checks'
      write lib/effect.zsh "print ran > $TREE/ran"
      When call check_syntax $TREE
      The status should equal 0
      The stdout should include 'lib/effect.zsh: zsh -n passed'
      The path "$TREE/ran" should not be exist
    End

    It 'fails when there is nothing to check'
      rm -rf $TREE
      mkdir -p $TREE
      When call check_syntax $TREE
      The status should equal 1
      The stdout should equal ''
      The stderr should include 'found no scripts to check'
    End
  End

  Describe 'test step'
    It 'runs the vendored runner from the repo root and reports OK'
      When call check_tests $TREE
      The status should equal 0
      The line 1 of stdout should equal "runner ran in $TREE"
      The line 2 of stdout should end with '  OK       [provision]       test suite: ShellSpec passed'
      The stderr should equal ''
    End

    It "fails with the runner's exit code, after passing its report through"
      write_runner 101
      When call check_tests $TREE
      The status should equal 101
      The stdout should equal "runner ran in $TREE"
      The stderr should include '  FAIL     [provision]       test suite: ShellSpec exited 101; its report above names the failures'
    End

    It 'fails when the vendored runner is missing'
      rm -rf $TREE/tests
      When call check_tests $TREE
      The status should equal 1
      The stderr should include 'tests/vendor/shellspec/shellspec is missing'
    End
  End

  Describe 'the whole gate'
    It 'passes when both steps pass, under the check module'
      When call check_main $TREE
      The status should equal 0
      The line 1 of stdout should end with '[check]           start — 6 items'
      The stdout should include '[check]           finish — 0 changed · 6 ok · 0 failed'
      The stderr should equal ''
    End

    It 'fails on a syntax error, and still runs the suite'
      write lib/broken.zsh 'if then'
      When call check_main $TREE
      The status should equal 1
      The stdout should include 'test suite: ShellSpec passed'
      The stderr should include 'lib/broken.zsh'
    End

    It 'fails on a failing suite'
      write_runner 101
      When call check_main $TREE
      The status should equal 1
      The stdout should include '· 5 ok · 1 failed'
      The stderr should include 'ShellSpec exited 101'
    End
  End
End
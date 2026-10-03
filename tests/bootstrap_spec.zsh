# Fixture tests for bootstrap.zsh (ADR-0003, docs/architecture.md §3; FR-1,
# CR-6, CR-15). The loader runs exactly as the pasted command runs it:
# /bin/zsh -f -c "<script text>" bootstrap [options]. bin/provision,
# xcode-select and sleep are stubs, and clones come from a local repository,
# so nothing touches the network or the machine.

Describe 'bootstrap.zsh'
  SCRIPT="$SHELLSPEC_PROJECT_ROOT/bootstrap.zsh"
  WORK="$SHELLSPEC_TMPBASE/bootstrap"
  REAL_GIT=$(command -v git)
  ESC=$'\e'

  # The stub reports its arguments and one line of stdin, then exits as told.
  write_provision_stub() {
    mkdir -p $1/bin
    print -r -- '#!/bin/zsh -f
IFS= read -r line
print -r -- "provision ran: args=[$*] stdin=[$line]"
exit ${STUB_PROVISION_RC:-0}' > $1/bin/provision
  }

  # A stand-in for the GitHub repository: one commit holding the stub.
  make_origin() {
    write_provision_stub $WORK/origin
    git -C $WORK/origin init --quiet
    git -C $WORK/origin add bin/provision
    git -C $WORK/origin -c user.name=test -c user.email=test@example.invalid \
      commit --quiet -m 'stub checkout'
  }

  # write_tool <name> <body>: an executable on the stub PATH. Each stub
  # appends its arguments to $WORK/<name>.calls, so tests can see every call.
  write_tool() {
    print -r -- "#!/bin/zsh -f
print -r -- \"\$*\" >> $WORK/$1.calls
$2" > $WORK/stubs/$1
    chmod +x $WORK/stubs/$1
  }

  setup() {
    rm -rf $WORK
    mkdir -p $WORK/stubs $WORK/home
    unset NO_COLOR STUB_PROVISION_RC
    export HOME=$WORK/home
    export DOTFILES_DIR=$WORK/home/.dotfiles
    export DOTFILES_REPO_URL=$WORK/origin
    export DOTFILES_CLT_GIT=$REAL_GIT
    export PATH=$WORK/stubs:$PATH
    write_tool xcode-select 'exit 0'
    write_tool sleep 'exit 0'
  }
  BeforeEach 'setup'

  # ShellSpec leaves stdin alone unless an example supplies Data, so a suite
  # started from a terminal would hand the keyboard to the stub's `read` and
  # wait for it. Only the stdin example runs the loader without the redirect.
  loader()            { /bin/zsh -f -c "$(<$SCRIPT)" bootstrap "$@" </dev/null }
  loader_with_stdin() { /bin/zsh -f -c "$(<$SCRIPT)" bootstrap "$@" }

  Describe 'with an existing checkout (FR-1.3, CR-6)'
    # A git that only records being called: any call would be a pull or clone.
    use_recording_git() {
      write_tool git 'exit 0'
      export DOTFILES_CLT_GIT=$WORK/stubs/git
    }
    Before 'write_provision_stub $DOTFILES_DIR' 'use_recording_git'

    It 'runs it as it stands and runs no git command'
      When run loader
      The status should equal 0
      The stdout should equal 'provision ran: args=[] stdin=[]'
      The stderr should equal ''
      The path "$WORK/git.calls" should not be exist
      The path "$WORK/xcode-select.calls" should not be exist
    End

    It 'passes options through (--check)'
      When run loader --check
      The stdout should equal 'provision ran: args=[--check] stdin=[]'
    End

    It 'passes several options through, in order'
      When run loader --check --upgrade
      The stdout should equal 'provision ran: args=[--check --upgrade] stdin=[]'
    End

    It 'leaves stdin to bin/provision, so prompts can read it'
      Data 'typed by the user'
      When run loader_with_stdin
      The stdout should equal 'provision ran: args=[] stdin=[typed by the user]'
    End

    It "exits with bin/provision's exit code"
      export STUB_PROVISION_RC=2
      When run loader
      The status should equal 2
      The stdout should include 'provision ran'
    End

    It 'runs bin/provision even without its executable bit'
      chmod -x $DOTFILES_DIR/bin/provision
      When run loader
      The status should equal 0
      The stdout should include 'provision ran'
    End
  End

  Describe 'without a checkout'
    Before 'make_origin'

    It 'clones into a missing directory, reports CHANGED, then runs the clone'
      When run loader --upgrade
      The status should equal 0
      The line 1 of stdout should end with '  CHANGED  [bootstrap]       ~/.dotfiles: cloned — verified'
      The line 2 of stdout should equal 'provision ran: args=[--upgrade] stdin=[]'
      The stderr should equal ''
      The path "$DOTFILES_DIR/.git" should be directory
    End

    It 'clones into an empty directory'
      mkdir -p $DOTFILES_DIR
      When run loader
      The status should equal 0
      The line 1 of stdout should include 'cloned — verified'
      The line 2 of stdout should include 'provision ran'
    End

    It 'shows a directory outside HOME by its full path'
      export DOTFILES_DIR=$WORK/elsewhere
      When run loader
      The line 1 of stdout should end with "  CHANGED  [bootstrap]       $WORK/elsewhere: cloned — verified"
      The line 2 of stdout should include 'provision ran'
    End

    It 'prints no color when output is not a terminal (FR-15.7)'
      When run loader
      The stdout should not include "$ESC"
    End

    It 'starts each line with a HH:MM:SS time (§8.5)'
      When run loader
      The line 1 of stdout should match pattern '[0-2][0-9]:[0-5][0-9]:[0-5][0-9]  CHANGED*'
      The line 2 of stdout should include 'provision ran'
    End

    Describe 'in check mode (FR-16.1)'
      It 'reports one DIFF, changes nothing and exits 0'
        export DOTFILES_CLT_GIT=$WORK/no-such-git
        When run loader --check
        The status should equal 0
        The stdout should end with '  DIFF     [bootstrap]       ~/.dotfiles: no checkout — would change'
        The lines of stdout should equal 1
        The stderr should equal ''
        The path "$DOTFILES_DIR" should not be exist
        The path "$WORK/xcode-select.calls" should not be exist
      End

      It 'finds --check among other options'
        When run loader --upgrade --check
        The status should equal 0
        The stdout should include 'no checkout — would change'
        The path "$DOTFILES_DIR" should not be exist
      End
    End

    Describe 'failures: one FAIL on stderr with a remedy, exit 1'
      It 'a failed clone, with git'"'"'s last line inside the FAIL'
        export DOTFILES_REPO_URL=$WORK/no-such-repo
        When run loader
        The status should equal 1
        The stdout should equal ''
        The lines of stderr should equal 1
        The stderr should include '  FAIL     [bootstrap]       ~/.dotfiles: git clone failed (fatal: '
        The stderr should end with ' — check the network connection, then paste the command again'
        The path "$DOTFILES_DIR/bin/provision" should not be exist
      End

      It 'a clone that holds no bin/provision'
        git -C $WORK/origin rm --quiet bin/provision
        git -C $WORK/origin -c user.name=test -c user.email=test@example.invalid \
          commit --quiet -m 'not the dotfiles repo'
        When run loader
        The status should equal 1
        The stdout should equal ''
        The stderr should include 'expected bin/provision in the clone, found none — check that'
      End

      It 'a directory that holds other files, which stay untouched'
        mkdir -p $DOTFILES_DIR
        print -r -- 'mine' > $DOTFILES_DIR/.zshrc
        When run loader
        The status should equal 1
        The stdout should equal ''
        The stderr should end with '  FAIL     [bootstrap]       ~/.dotfiles: expected a checkout or an empty directory, found other files — move it aside or set DOTFILES_DIR to another path, then paste the command again'
        The contents of file "$DOTFILES_DIR/.zshrc" should equal 'mine'
        The path "$DOTFILES_DIR/.git" should not be exist
      End

      It 'a regular file where the directory should be'
        print -r -- 'mine' > $DOTFILES_DIR
        When run loader
        The status should equal 1
        The stderr should include 'expected a checkout or an empty directory'
        The contents of file "$DOTFILES_DIR" should equal 'mine'
      End
    End

    Describe 'when the Command Line Tools are missing (FR-1.2, CR-15)'
      # The tools "finish installing" during the nth sleep: the stub puts a
      # working git where the loader is polling for one.
      tools_arrive_on_sleep() {
        export DOTFILES_CLT_GIT=$WORK/clt/git
        write_tool sleep "
(( \$(wc -l < $WORK/sleep.calls) >= $1 )) || exit 0
mkdir -p $WORK/clt
print -r -- '#!/bin/sh
exec $REAL_GIT \"\$@\"' > $WORK/clt/git
chmod +x $WORK/clt/git"
      }

      It 'starts the installer once, prints one ACTION, waits, then clones and runs'
        tools_arrive_on_sleep 3
        When run loader --upgrade
        The status should equal 0
        The lines of stdout should equal 3
        The line 1 of stdout should end with '  ACTION   [bootstrap]       Command Line Tools: Click Install in the dialog that just opened; this run continues by itself when the install finishes. If you closed the dialog, press Ctrl-C and paste the command again.'
        The line 2 of stdout should include 'cloned — verified'
        The line 3 of stdout should equal 'provision ran: args=[--upgrade] stdin=[]'
        The stderr should equal ''
        The contents of file "$WORK/xcode-select.calls" should equal '--install'
        The contents of file "$WORK/sleep.calls" should equal "5${SHELLSPEC_LF}5${SHELLSPEC_LF}5"
      End

      It 'does not start the installer when the tools are present'
        When run loader
        The stdout should not include 'ACTION'
        The stdout should include 'provision ran'
        The path "$WORK/xcode-select.calls" should not be exist
      End

      It 'fails with a remedy when the installer cannot be started'
        export DOTFILES_CLT_GIT=$WORK/clt/git
        write_tool xcode-select 'print -u2 -r -- "xcode-select: error: boom"; exit 1'
        When run loader
        The status should equal 1
        The stdout should equal ''
        The stderr should end with '  FAIL     [bootstrap]       Command Line Tools: could not start the installer (xcode-select: error: boom) — if an install is already running, wait for it to finish; then paste the command again'
        The path "$WORK/sleep.calls" should not be exist
        The path "$DOTFILES_DIR" should not be exist
      End
    End
  End

  Describe 'a download cut short'
    # Everything but the final `main "$@"` line: what a broken connection
    # could leave in the command substitution.
    truncated_loader() {
      local text=$(<$SCRIPT)
      /bin/zsh -f -c "${text%main*}" bootstrap "$@" </dev/null
    }

    It 'runs nothing'
      write_provision_stub $DOTFILES_DIR
      When run truncated_loader
      The status should equal 0
      The stdout should equal ''
      The stderr should equal ''
    End
  End

  Describe 'conventions'
    It 'uses the -f shebang (DEC-18)'
      The line 1 of contents of file "$SCRIPT" should equal '#!/bin/zsh -f'
    End

    It 'has one top-level command, the call to main on the last line'
      # Lines at column 0 that are not comments, blank, a function header or
      # a closing brace: there must be exactly one.
      top_level() { grep -v -E '^(#|$|[[:space:]]|[a-z_]+\(\) \{$|\}$)' $SCRIPT }
      When call top_level
      The stdout should equal 'main "$@"'
    End
  End
End
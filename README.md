# dotfiles

A zsh program that takes an Apple Silicon Mac from first desktop to fully
configured: packages and apps, language runtimes, dotfiles, git and SSH
identity, and macOS settings. Every change is declared in a data file and
applied idempotently, so re-running converges the machine back to the declared
state and a second run changes nothing.

> **Status: under construction.** Nothing here is ready to run yet. The
> requirements and design live in [`docs/`](docs/).

## Before you run it

Update macOS to the latest available version first. The program does not
install macOS updates.

## Usage

Paste into Terminal:

```sh
/bin/zsh -f -c "$(curl -fsSL https://raw.githubusercontent.com/panningforbacon/dotfiles/main/bootstrap.zsh)"
```

This command does not work yet: `bootstrap.zsh` arrives with the bootstrap
story.

## Development

Run the quality gate before every commit:

```sh
scripts/check
```

It needs nothing installed: the test framework
([ShellSpec](https://github.com/shellspec/shellspec) 0.28.1) is vendored under
`tests/vendor/`. The gate has two steps, and both always run:

1. **Syntax.** `zsh -n` on `bootstrap.zsh`, every file in `bin/`, `lib/`,
   `modules/` and `scripts/`, and the zsh files under `home/` (the startup
   files such as `.zshrc`, plus any `*.zsh`). One `OK` or `FAIL` line per file.
2. **Tests.** The whole suite in `tests/*_spec.zsh`. ShellSpec prints its own
   report, which names any failing example with its file and line.

It exits 0 when both steps pass and 1 otherwise. Every file in the four script
directories is checked as zsh, so keep other kinds of file out of them.

To run one spec file, or one example by line number, while working on it:

```sh
tests/vendor/shellspec/shellspec tests/log_spec.zsh
tests/vendor/shellspec/shellspec tests/log_spec.zsh:42
```

## License

[MIT](LICENSE)
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

## License

[MIT](LICENSE)

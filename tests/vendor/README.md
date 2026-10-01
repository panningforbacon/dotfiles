# Vendored code

Copied into this repo and committed, so tests run straight after a clone, 
before Homebrew exits. Never edit these files; replace them.

| Directory | Upstream | Version | Commit | Files kept |
| --- | --- | --- | --- | --- | --- |
| `shellspec/` | https://github.com/shellspec/shellspec | 0.28.1 | 90e48c950239f3b8a9fdfa3e869592872c77b981 | `shellspec`, `lib/`, `libexec/`, `LICENSE` |

to update: delete this directory, repeat the copy at the new tag, verify the
commit, run the suite, and commit as `chore(test): bump ShellSpec to <version>`.
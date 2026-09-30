# ADR-0006: macOS settings manifest format

| | |
| --- | --- |
| **Status** | Accepted — PO override of the tech lead's pipe-delimited format |
| **Date** | 2026-09-28 |
| **Deciders** | PO (format), tech lead (grouping, flags, parsing) |
| **Related** | DEC-17R, DEC-22, DEC-23, DEC-24 (withdrawn), DEC-25; FR-10, §8.4, §8.5, M4, NFR-4; CR-12, CR-16 |

## Context

- §8.4 states requirements as **intents**. Some intents need several keys (tap to click needs three), and some may need a mechanism other than `defaults write` on current macOS (FR-10.1).
- §8.5 prints **one compact line per intent**, not per key.
- Some intents need a logout.
- The PO wants the file to read like the `defaults write` commands it replaces.

## Decision

The manifest is `macos/defaults.conf`:

```text
## Free-text comments start with a double hash and are ignored.

# trackpad: tap-to-click
com.apple.AppleMultitouchTrackpad Clicking -bool true
com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# trackpad: three-finger drag [logout]
com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true

# screenshots: save location
com.apple.screencapture location -string "~/Desktop/Screenshots"
```

- **Headers group lines (DEC-22).** `# <area>: <intent>` starts one logical setting, and every line up to the next header belongs to it. The area becomes the log module (`defaults.<area>`) and the intent becomes the label.
- **Flag on the header (DEC-23).** `[logout]` adds `needs logout` to the result and to the summary.
- **Setting lines.** `<domain> <key> -<type> <value>`, with the same types as `defaults write` (`-bool`, `-int`, `-float`, `-string`).
- **No escape hatch (DEC-24 withdrawn).** Every remaining §8.4 row is a plain `defaults` key. If spike S-7 finds an intent that needs another mechanism, a new ADR adds one.
- **Parsed, never executed (DEC-25).** Lines are split with zsh's shell-style word splitting, so quotes work. They are never passed to `eval`. A leading `~` in a value is expanded explicitly.
- **Verification** reads each key back with `defaults read` and normalizes by type before comparing: a `bool` reads back as `1`/`0`. An intent is `CHANGED` only when every key in its group reads back as desired. Otherwise it is `FAIL` with the read-back value.

## Rejected alternatives

- **Pipe-delimited table** (`area | intent | domain | key | type | value | flags`). Easy to parse. Overruled: harder to read than the commands it describes.
- **Executing each line as a shell command.** Simplest implementation, but any typo becomes arbitrary code execution, and there is no read-back step.
- **One header per key.** Would print one line per key, violating §8.5's one-line-per-intent rule.

## Consequences

- A line starting with a single `#` is structural. A free comment written with one `#` is parsed as a header, and the parser rejects it with a `FAIL` naming the line.
- Adding a setting is two lines (NFR-4).
- M4 evidence can be recorded per header.

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | Accepted during chartering (PO override). |
| 0.2 | 2026-09-28 | Removed the `[fda]` flag (CR-12) and the `@function` escape hatch (DEC-24 withdrawn after CR-16). |

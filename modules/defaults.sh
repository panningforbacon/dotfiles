#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$DOTFILES_DIR/scripts/lib.sh"

trap 'err_trap' ERR


# ── Helpers ────────────────────────────────────────────────────────────────────

get_macos_version() {
  sw_vers -productVersion | cut -d. -f1
}


_set_default() {
  local domain="$1"
  local key="$2"
  local type="$3"
  local value="$4"
 
  # Normalize the expected value to match what `defaults read` returns.
  # `defaults read` always outputs booleans as 0/1, never true/false.
  local expected
  case "$value" in
    true)  expected="1" ;;
    false) expected="0" ;;
    *)     expected="$value" ;;
  esac
 
  local current
  current="$(defaults read "$domain" "$key" 2>/dev/null || echo "__unset__")"
 
  if [[ "$current" == "$expected" ]]; then
    printf "  \033[2m[NO CHANGE]\033[0m  %s  %s\n" "$domain" "$key"
    return 0
  fi
 
  defaults write "$domain" "$key" "$type" "$value"
 
  local written
  written="$(defaults read "$domain" "$key" 2>/dev/null || echo "__read_failed__")"
 
  if [[ "$written" == "$expected" ]]; then
    printf "  \033[0;32m[SUCCESS]\033[0m    %s  %s = %s\033[2m (was: %s)\033[0m\n" \
      "$domain" "$key" "$value" "$current"
  else
    printf "  \033[0;31m[FAILURE]\033[0m    %s  %s — expected '%s', got '%s'\n" \
      "$domain" "$key" "$expected" "$written" >&2
  fi
}


# Typed convenience wrappers — keeps the call sites readable.
set_bool()   { _set_default "$1" "$2" "-bool"   "$3"; }
set_str()    { _set_default "$1" "$2" "-string" "$3"; }
set_int()    { _set_default "$1" "$2" "-int"    "$3"; }
set_float()  { _set_default "$1" "$2" "-float"  "$3"; }


require_full_disk_access() {
  # Guard clause: blocks until Terminal has Full Disk Access, or bails out.
  # Can't script the grant itself — TCC's whole point is that a human has
  # to click it. This just makes sure nothing downstream runs against a
  # write that silently landed in the wrong (unsandboxed) plist.

  # Cheap probe: TCC.db itself is FDA-gated, so being able to read it
  # proves we have the access we need. No FDA -> permission denied here.
  if sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" \
    "select * from access limit 1" &>/dev/null; then
    return 0   # already granted, nothing to do
  fi

  info "Full Disk Access is required before some defaults can be written."

  echo "Opening System Settings..."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
  echo ""
  echo "Add this terminal app (or VS Code/iTerm2/whatever) to the list and enable it, then confirm below."
  echo "(If it's already listed, toggle it off and back on — stale grants happen.)"
  echo ""

  local confirm
  while true; do
      read -rp "Granted? [y/n] " confirm
      case "$confirm" in
          [Yy]*) break ;;
          [Nn]*) echo "Waiting. Toggle it, then say y." ;;
          *) echo "y or n." ;;
      esac
  done

  # Re-probe — don't just trust the click, verify it actually took
  if ! sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" \
      "select * from access limit 1" &>/dev/null; then
      echo "Still can't read TCC.db. Either the grant didn't take, or this"
      echo "terminal process needs a restart before TCC will honor it."
      return 1
  fi

  return 0
}


# ── Main ────────────────────────────────────────────────────────────────────

section "macOS defaults"
require_macos

MACOS_VERSION="$(get_macos_version)"

if (( MACOS_VERSION < 15 )); then
  warn "macOS $MACOS_VERSION detected — defaults were written for macOS 15 (Sequoia) and above."
  warn "Some keys may not exist or behave differently. Verify before applying."
else
  dim "macOS version: $MACOS_VERSION"
fi

# Close System Preferences if open — an open pref pane will overwrite changes
# made to its domain as soon as it's closed.
osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true
osascript -e 'tell application "System Settings" to quit'    2>/dev/null || true


# ────────────────────────────────────────────────────────────────────────────────

printf "\nDock...\n"

# Icon size in pixels
set_int "com.apple.dock" "tilesize" "48"

# Auto-hide the Dock
set_bool "com.apple.dock" "autohide" "true"

# Remove the auto-hide delay (show instantly)
set_float "com.apple.dock" "autohide-delay" "0"

# Speed up the auto-hide animation
set_float "com.apple.dock" "autohide-time-modifier" "0.25"

# Don't show recent applications
set_bool "com.apple.dock" "show-recents" "false"

# Minimise windows using the scale effect (faster than genie)
set_str "com.apple.dock" "mineffect" "scale"

# Don't rearrange Spaces based on most recent use
set_bool "com.apple.dock" "mru-spaces" "false"


# ────────────────────────────────────────────────────────────────────────────────

printf "\nFinder...\n"

# Show all filename extensions
set_bool "com.apple.finder" "AppleShowAllExtensions" "true"

# Show the path bar at the bottom of Finder windows
set_bool "com.apple.finder" "ShowPathbar" "true"

# Show the status bar at the bottom of Finder windows
set_bool "com.apple.finder" "ShowStatusBar" "true"

# Display full POSIX path in the Finder window title
set_bool "com.apple.finder" "UseFullPathInTitle" "true"

# Search the current folder by default (not This Mac)
set_str "com.apple.finder" "FXDefaultSearchScope" "SCcf"

# Don't warn when changing a file extension
set_bool "com.apple.finder" "FXEnableExtensionChangeWarning" "false"

# Don't write .DS_Store files on network or USB volumes
set_bool "com.apple.desktopservices" "DSDontWriteNetworkStores" "true"
set_bool "com.apple.desktopservices" "DSDontWriteUSBStores" "true"

# Default Finder view: list view
# Flwp = icon, Nlsv = list, clmv = column, glyv = gallery
set_str "com.apple.finder" "FXPreferredViewStyle" "Nlsv"

# Keep folders on top when sorting by name
set_bool "com.apple.finder" "FXSortFoldersFirst" "true"

# Show hidden files
set_bool "com.apple.finder" "AppleShowAllFiles" "true"

# New window opens to home directory
set_str "com.apple.finder" "NewWindowTarget" "PfHm"


# ────────────────────────────────────────────────────────────────────────────────

printf "\nMenu bar and system UI...\n"

# Show battery percentage
set_bool "com.apple.menuextra.battery" "ShowPercent" "true"

# Clock: show seconds
set_bool "com.apple.menuextra.clock" "ShowSeconds" "true"

# Clock: use 24-hour time
set_bool "com.apple.menuextra.clock" "Show24Hour" "true"


# ────────────────────────────────────────────────────────────────────────────────

printf "\nKeyboard...\n"

# Key repeat rate (lower = faster; default 6, minimum 1)
set_int "NSGlobalDomain" "KeyRepeat" "2"

# Delay before key repeat starts (lower = shorter; default 68, minimum 15)
set_int "NSGlobalDomain" "InitialKeyRepeat" "15"

# Disable auto-correct
set_bool "NSGlobalDomain" "NSAutomaticSpellingCorrectionEnabled" "false"

# Disable auto-capitalisation
set_bool "NSGlobalDomain" "NSAutomaticCapitalizationEnabled" "false"

# Disable smart dashes
set_bool "NSGlobalDomain" "NSAutomaticDashSubstitutionEnabled" "false"

# Disable smart quotes
set_bool "NSGlobalDomain" "NSAutomaticQuoteSubstitutionEnabled" "false"

# Disable period substitution on double-space
set_bool "NSGlobalDomain" "NSAutomaticPeriodSubstitutionEnabled" "false"

# Enable full keyboard access (Tab moves focus to all controls, not just fields)
set_int "NSGlobalDomain" "AppleKeyboardUIMode" "3"


# ────────────────────────────────────────────────────────────────────────────────

printf "\nTrackpad...\n"

# Enable tap to click (no physical press required)
set_bool "com.apple.driver.AppleBluetoothMultitouch.trackpad" "Clicking" "true"
set_bool "com.apple.AppleMultitouchTrackpad" "Clicking" "true"
set_int  "NSGlobalDomain" "com.apple.mouse.tapBehavior" "1"

# Tracking speed (0–3; default ~1.5, higher = faster)
set_float "NSGlobalDomain" "com.apple.trackpad.scaling" "2"

# Enable three-finger drag
set_bool "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadThreeFingerDrag" "true"
set_bool "com.apple.AppleMultitouchTrackpad" "TrackpadThreeFingerDrag" "true"


# ────────────────────────────────────────────────────────────────────────────────

printf "\nScreen...\n"

# Require password immediately after sleep or screen saver
set_int "com.apple.screensaver" "askForPassword" "1"
set_int "com.apple.screensaver" "askForPasswordDelay" "0"

# Save screenshots to ~/Desktop/Screenshots
SCREENSHOT_DIR="$HOME/Desktop/Screenshots"
mkdir -p "$SCREENSHOT_DIR"
set_str "com.apple.screencapture" "location" "$SCREENSHOT_DIR"

# Save screenshots as PNG (options: png, jpg, pdf, tiff, bmp, psd, gif)
set_str "com.apple.screencapture" "type" "png"

# Disable screenshot thumbnail preview
set_bool "com.apple.screencapture" "show-thumbnail" "false"

# Enable subpixel font rendering on non-Apple displays
set_int "NSGlobalDomain" "AppleFontSmoothing" "1"


# ────────────────────────────────────────────────────────────────────────────────

printf "\nMission Control and Spaces...\n"

# Faster Mission Control animation
set_float "com.apple.dock" "expose-animation-duration" "0.1"

# Group windows by application in Mission Control
set_bool "com.apple.dock" "expose-group-by-app" "true"

# Don't automatically rearrange Spaces (set in Dock section too; belt + braces)
set_bool "com.apple.dock" "mru-spaces" "false"


# ────────────────────────────────────────────────────────────────────────────────

printf "\nTextEdit...\n"

# Default to plain text, not rich text
set_int "com.apple.TextEdit" "RichText" "0"

# Open and save files as UTF-8
set_int "com.apple.TextEdit" "PlainTextEncoding" "4"
set_int "com.apple.TextEdit" "PlainTextEncodingForWrite" "4"


# ────────────────────────────────────────────────────────────────────────────────

printf "\nActivity Monitor...\n"

# Show all processes, not just the current user's
set_int "com.apple.ActivityMonitor" "ShowCategory" "0"

# Sort by CPU usage by default
set_str "com.apple.ActivityMonitor" "SortColumn" "CPUUsage"
set_int "com.apple.ActivityMonitor" "SortDirection" "0"


# ── App-specific defaults ────────────────────────────────────────────────────────────────────

section "App-specific defaults"

# Guard-clause
require_full_disk_access || { die "Aborting: no FDA, writes would be silently discarded."; }


printf "\nSafari (developer settings)...\n"

# Enable the Develop menu
set_bool "com.apple.Safari" "IncludeDevelopMenu" "true"

# Enable Web Inspector
set_bool "com.apple.Safari" "WebKitDeveloperExtrasEnabledPreferenceKey" "true"
set_bool "com.apple.Safari" "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" "true"

# Don't open files automatically after download
set_bool "com.apple.Safari" "AutoOpenSafeDownloads" "false"


# ── Restart affected services ────────────────────────────────────────────────────────────────────
# Changes to most domains don't take effect until the relevant process is
# restarted. We target only the processes whose domains we actually touched.
# ─────────────────────────────────────────────────────────────────────────────────────────────────

printf "\nRestarting affected services...\n"

# Dock (Dock, Mission Control, autohide, spaces settings)
killall Dock 2>/dev/null && dim "Restarted: Dock" || true

# Finder (all Finder prefs)
killall Finder 2>/dev/null && dim "Restarted: Finder" || true

# SystemUIServer (menu bar — battery, clock)
killall SystemUIServer 2>/dev/null && dim "Restarted: SystemUIServer" || true

# cfprefsd flushes the preferences cache — prevents stale reads on next launch
killall cfprefsd 2>/dev/null && dim "Flushed: cfprefsd" || true


info "macOS defaults applied. Some settings require a logout/login to take full effect."

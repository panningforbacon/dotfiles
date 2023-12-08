

#### HELPER FUNCTIONS ####

# adds an application to macOS Dock
# usage: add_app_to_dock "Application Name"
# example add_app_to_dock "/System/Applications/Music.app"
function add_app_to_dock {
  app="${1}"
  if open -Ra "${app}"; then
    echo "Adding '$app' to the dock..."
    defaults write com.apple.dock persistent-apps -array-add \
    "<dict>
      <key>tile-data</key>
      <dict>
        <key>file-data</key>
        <dict>
          <key>_CFURLString</key>
          <string>${app}</string>
          <key>_CFURLStringType</key>
          <integer>0</integer>
        </dict>
      </dict>
    </dict>"
  else
    echo "ERROR: Application $1 not found."
  fi
}


# adds a folder to macOS Dock
# usage: add_folder_to_dock "Folder Path" -a n -d n -v n
# example: add_folder_to_dock "~/Downloads" -a 2 -d 0 -v 1
# key:
# -a or --arrangement
#   1 -> Name
#   2 -> Date Added
#   3 -> Date Modified
#   4 -> Date Created
#   5 -> Kind
# -d or --displayAs
#   0 -> Stack
#   1 -> Folder
# -v or --showAs
#   0 -> Automatic
#   1 -> Fan
#   2 -> Grid
#   3 -> List
function add_folder_to_dock {
  folder="${1}"
  arrangement="1"
  displayAs="0"
  showAs="0"

  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -a|--arrangement)
        if [[ $2 =~ ^[1-5]$ ]]; then
          arrangement="${2}"
        fi
        ;;
      -d|--displayAs)
        if [[ $2 =~ ^[0-1]$ ]]; then
          displayAs="${2}"
        fi
        ;;
      -v|--showAs)
        if [[ $2 =~ ^[0-3]$ ]]; then
          showAs="${2}"
        fi
        ;;
    esac
    shift
  done

  if [ -d "$folder" ]; then
    echo "Adding $folder to the dock..."
    defaults write com.apple.dock persistent-others -array-add \
      "<dict>
        <key>tile-data</key>
        <dict>
          <key>arrangement</key>
          <integer>${arrangement}</integer>
          <key>displayas</key>
          <integer>${displayAs}</integer>
          <key>file-data</key>
          <dict>
            <key>_CFURLString</key>
            <string>file://${folder}</string>
            <key>_CFURLStringType</key>
            <integer>15</integer>
          </dict>
          <key>file-type</key>
          <integer>2</integer>
          <key>showas</key>
          <integer>${showAs}</integer>
        </dict>
        <key>tile-type</key>
        <string>directory-tile</string>
      </dict>"
  else
    echo "ERROR: Folder $folder not found."
  fi
}

function add_large_spacer_to_dock {
    defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="spacer-tile";}'
}

function add_small_spacer_to_dock {
    defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="small-spacer-tile";}'
}





declare -a folders=(
    ~/Downloads
);


########################################
## RESET
##

# Reset dock to factory settings
defaults delete com.apple.dock

# Clear apps & others from dock
defaults delete com.apple.dock persistent-apps
defaults delete com.apple.dock persistent-others

# Restart
killall Dock


########################################
## GENERAL SETTINGS
##

# Indicate hidden apps transparent?
defaults write com.apple.dock showhidden -bool true

# Show recent apps in dock?
defaults write com.apple.dock show-recents -bool false

# Only show active apps, removing them once closed?
defaults write com.apple.dock static-only -bool false

# Hide other open apps when selecting an app?
defaults write com.apple.dock single-app -bool false

# Open stacks or show app windows with an upward scroll/swipe on the app?
defaults write com.apple.dock scroll-to-open -bool false

# Close apps with a 'suck' animation back into the dock?
defaults write com.apple.dock mineffect suck

# Auto-hide: What factor should the auto-hide time be multiplied by?
defaults write com.apple.dock autohide-time-modifier -float 0.5








# Add dock elements
add_app_to_dock "/System/Applications/Utilities/Terminal.app"
add_app_to_dock "/Applications/Google Chrome.app"
add_app_to_dock "/Applications/Visual Studio Code.app"
add_app_to_dock "/System/Applications/System Preferences.app"
add_large_spacer_to_dock
add_folder_to_dock "~/Downloads" --arrangement 3 --displayAs 1 --showAs 3
add_folder_to_dock "~/Downloads" --arrangement 3 --displayAs 1 --showAs 3






# Restart
killall Dock

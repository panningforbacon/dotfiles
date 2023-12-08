#!/bin/bash


#### HELPER FUNCTIONS ####

SCRIPTNAME=$(basename "$0")
echo() {
  command echo "[$SCRIPTNAME] $*"
}

function command_exists {
  command_name=$1
  type "$command_name" &>/dev/null
}


echo ""
echo "Ensuring script running with root privileges"
if [ "$EUID" -ne 0 ]; then
  sudo bash "$0" "$@"
  exit $?
fi

echo ""
echo "=== Xcode Command Line Tools ==="
echo "Checking installation..."
xcode_err=$(xcode-select --print-path 2>&1 1>/dev/null)
if [[ "$xcode_err" == "xcode-select: error: unable to get active developer directory"* ]]; then
  echo "Installing Xcode Command Line Tools"
  xcode-select --install

  # User confirmation...
  while true; do
    read -p "Enter 'Y' once Xcode Command Line Tools is done installing. Else, 'N'. [Y/N]" yn
    case $yn in
      [Yy] ) break;;
      [Nn] ) echo "Exiting script..."; exit;;
      * ) echo "Please answer yes or no. [Y/N]";;
    esac
  done
  echo "Onward!"

elif [[ $xcode_err ]]; then
  echo "Error: Unrecognized error from 'xcode-select --print-path': $xcode_err"
  exit 1
fi

echo "Checking developer directory..."
xcode_dir=$(xcode-select --print-path 1>&1 2>/dev/null)
if [[ ! -d "$xcode_dir" ]]; then
  echo "Attempting to reset developer directory"
  sudo xcode-select --reset
fi

echo "Checking for updates..."
if softwareupdate --list | grep "Command Line Tools"; then
  echo "Installing updates"
  sfotwareupdate --all --install --force 
fi


echo ""
echo "=== Homebrew ==="
echo "Checking installation..."
if ! command_exists brew; then
  echo "Installing"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  echo "Removing core & cask package taps to save space"
  u $SUDO_USER -c "brew untap homebrew/core"
  u $SUDO_USER -c "brew untap homebrew/cask"
else
  echo "Homebrew already installed. Checking for updates"
  su $SUDO_USER -c "brew update"
  su $SUDO_USER -c "brew upgrade"
fi


echo ""
echo "=== PATH variable ==="
echo "Prepending /usr/local/bin..."
PACKAGE_DIR="/usr/local/bin"
if [[ ! "$PATH" == "$PACKAGE_DIR:"* ]]; then
  echo "Error: PATH does not begin with /usr/local/bin. It's best to fix this manually in the /etc/paths file."
  exit 1
fi


echo ""
echo "==> ./brew_installs.sh"
sudo -u $SUDO_USER ./brew_installs.sh

echo ""
echo "==> ./macos_settings.sh"
sudo -u $SUDO_USER ./macos_settings.sh

echo ""
echo "============================="
echo ""
echo "All done. 👏"
exit 0

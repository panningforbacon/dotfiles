#!/bin/bash


# Ensure sudo privileges
if [[ $EUID -ne 0 ]]; then
    sudo echo "Acquiring sudo privileges..."
fi


# Check if Xcode Command Line Tools are already installed
xcode-select -p &>/dev/null
if [ $? -ne 0 ]; then
    echo "Xcode Command Line Tools not found. Installing them now."
    xcode-select --install
else
    echo "Xcode Command Line Tools are already installed."
fi

check_installation() {
    # Loop until the Xcode Command Line Tools are installed...
    until xcode-select -p &>/dev/null; do
        echo "Waiting for Xcode Command Line Tools to finish installing..."
        sleep 5
    done
    echo "Xcode Command Line Tools installation completed."
}
check_installation


# Check for Xcode Command Line Tools updates
echo "Checking for updates to Xcode Command Line Tools..."
softwareupdate -l | grep "\*.*Command Line" &>/dev/null
if [ $? -eq 0 ]; then
    echo "Updates found for Xcode Command Line Tools. Installing updates..."
    softwareupdate -i -a
else
    echo "No updates found for Xcode Command Line Tools."
fi


echo "Installation and update process completed."

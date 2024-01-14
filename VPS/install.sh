#!/bin/bash
#
# Post-Installation Proxy Script
# ------------------------
# This script automates the setup of a fresh proxy for server by installing and configuring Ubuntu Server
#
# Author: ThePhaseless
# Date:   January 1, 2024
#

# Update the package list and upgrade existing packages
sudo apt update
sudo apt upgrade -y

# Ask if user wants to change password
read -r -p "Do you want to change the password? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
	sudo passwd "$USER"
fi

# Install VS Code
./general/setup_vscode.sh

# Install Zsh and Oh-My-Zsh
## For user
./general/setup_zsh.sh
## For root
sudo ./general/setup_zsh.sh

# Install Tailscale
./general/setup_tailscale.sh

# Make a tunnel with wireguard to DNS server
./setup_wireguard.sh

#!/bin/bash

# Exit immediately if any command fails
set -e

# Function to set permissions and ownership
set_permissions_ownership() {
	sudo chmod 755 "$1" -R
	sudo chown nobody:nogroup "$1" -R
}

# Set default values for environment variables from fireword.env
echo "Using these environment variables:"
if [ -f "$PWD"/.env ]; then
	echo "Using environment variables from .env"
else
	echo "No .env file found, creating one..."
	cp ./.env.example ./.env
	nano ./.env
fi

# shellcheck disable=SC1091
source ./.env

# Ask the user if envs are correct
read -r -p "Continue? (Y/n): "

# Apply sudo patch
./Scripts/remove_sudo_password.sh

# Create directories
echo "Creating directories..."
for directory in "$CONFIG_PATH" "$MEDIA_PATH" "$SSD_PATH" "$STORAGE_PATH"; do
	export directory
	echo "Creating $directory"
	sudo mkdir -p "$directory"
	set_permissions_ownership "$directory"
done
echo "Done."

# Update the package list and upgrade existing packages
echo "Updating system..."
sudo apt update
sudo apt fully-upgrade
sudo apt dist-upgrade
sudo unattended-upgrades
sudo fwupdmgr refresh
sudo fwupdmgr update

# Install Zsh and Oh-My-Zsh
## For user
../Scripts/setup_zsh.sh

## For root
sudo ../Scripts/setup_zsh.sh

# Install VS Code
../General/setup_vscode.sh

# Setup samba
./setup_samba.sh

# Setup Tailscale
../General/setup_tailscale.sh

# Install Docker and Docker Compose
../setup_docker.sh

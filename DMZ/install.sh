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
if [ -f "Docker/Compose/envs/.env" ]; then
	echo "Using environment variables from .env"
else
	echo "No .env file found, creating..."
	read -r -p "Press any key to edit .env... " -n1 -s
	cp Docker/Compose/envs/.env.example Docker/Compose/envs/.env
	nano Docker/Compose/envs/.env
fi

# shellcheck disable=SC1091
source Docker/Compose/envs/.env

# Ask the user if envs are correct
read -r -p "Continue? (Y/n): " input
case $input in
[nN][oO] | [nN])
	echo "Exiting..."
	exit 1
	;;
*)
	echo "Continuing..."
	;;
esac

# Create directories
echo "Creating directories..."
for directory in "$CONFIG_PATH" "$MEDIA_PATH" "$SSD_PATH" "$STORAGE_PATH"; do
	echo "Creating $directory"
	sudo mkdir -p "$directory"
	set_permissions_ownership "$directory"
done
echo "Done."

export CONFIG_PATH
export MEDIA_PATH
export SSD_PATH
export STORAGE_PATH

# Apply sudo patch
../General/remove_sudo_password.sh

# Update the package list and upgrade existing packages
echo "Updating system..."
sudo apt update
sudo apt full-upgrade -y
sudo apt dist-upgrade -y
sudo unattended-upgrades
sudo fwupdmgr update

# Install Zsh and Oh-My-Zsh
## For user
../General/setup_zsh.sh

## For root
sudo ../General/setup_zsh.sh

# Install VS Code
../General/setup_vscode.sh

# Setup Storage
read -r -p "Do you want to setup RAID10? (Y/n): " input
case $input in
[nN][oO] | [nN])
	echo "Skipping RAID10 setup..."
	;;
*)
	echo "Setting up RAID10..."
	./setup_raidz10.sh
	;;
esac

# Setup samba
./setup_samba.sh

# Install Screen Off Service
./setup_screen_off_service.sh

# Setup Tailscale
../General/setup_tailscale.sh

# Setup Wireguard
./setup_wireguard.sh

# Install Docker and Docker Compose
./setup_docker.sh

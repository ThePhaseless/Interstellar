#
# Post-Installation Proxy Script
# ------------------------
# This script automates the setup of a fresh proxy for server by installing and configuring Ubuntu Server
#
# Author: ThePhaseless
# Date:   January 1, 2024
#

# Check if upload_acme is in crontab, if not add it
echo "Checking if upload_acme.sh is in crontab..."
if crontab -l | grep -q 'upload_acme.sh'; then
	echo "upload_acme.sh already in crontab..."
else
	echo "Adding upload_acme.sh to crontab..."
	(
		crontab -l 2>/dev/null
		echo "0 4 * * * $PWD/upload_acme.sh"
	) | crontab -
	echo "Done..."
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

# Install Docker and Docker Compose
./general/setup_docker.sh

#
# Post-Installation Proxy Script
# ------------------------
# This script automates the setup of a fresh proxy for server by installing and configuring Ubuntu Server
#
# Author: ThePhaseless
# Date:   January 1, 2024
#

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

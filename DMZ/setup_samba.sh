#!/bin/bash

# Install SAMBA
echo "Installing SAMBA..."
sudo apt install samba wsdd -y

# Copy the SAMBA configuration file
echo "Copying SAMBA configuration file..."
sudo cp ./shares.conf /etc/samba/

# Include the SAMBA configuration file
echo "Including SAMBA configuration file..."
"include = /etc/samba/shares.conf" | sudo tee -a /etc/samba/smb.conf >/dev/null

echo "Restarting SAMBA..."
sudo systemctl restart smbd
echo "Done..."

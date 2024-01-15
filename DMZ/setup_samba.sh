#!/bin/bash

# Install SAMBA
echo "Installing SAMBA..."
sudo apt install samba wsdd -y

# Update the SAMBA configuration file
echo "Updating SAMBA configuration file..."
# Replace STORAGE_PATH with $STORAGE_PATH and SSD_PATH with $SSD_PATH
sed -i "s|STORAGE_PATH|$STORAGE_PATH|g" ./shares.conf
sed -i "s|SSD_PATH|$SSD_PATH|g" ./shares.conf

# Include the SAMBA configuration file
echo "Including SAMBA configuration file..."
"include = $PWD/shares.conf" | sudo tee -a /etc/samba/smb.conf

echo "Restarting SAMBA..."
sudo systemctl restart smbd
echo "Done..."

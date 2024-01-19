#!/bin/bash

# Install SAMBA
echo "Installing SAMBA..."
sudo apt install samba wsdd -y

# Update the SAMBA configuration file
echo "Updating SAMBA configuration file..."

# Include the SAMBA configuration file
echo "Including SAMBA configuration file..."
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
echo "include = /etc/samba/smb.conf.d/shares.conf" | sudo tee -a /etc/samba/smb.conf
sudo mkdir /etc/samba/smb.conf.d
sudo cp ./shares.conf /etc/samba/smb.conf.d/shares.conf

# Replace CONFIG_PATH and STORAGE_PATH with $CONFIG_PATH and $STORAGE_PATH
echo "Replacing CONFIG_PATH and STORAGE_PATH with $SSD_PATH and $STORAGE_PATH..."
sudo sed -i "s|SSD_PATH|$SSD_PATH|g" /etc/samba/smb.conf.d/shares.conf
sudo sed -i "s|STORAGE_PATH|$STORAGE_PATH|g" /etc/samba/smb.conf.d/shares.conf

echo "Restarting SAMBA..."
sudo systemctl restart smbd
echo "Done..."

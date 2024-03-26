#!/bin/bash

# Exit on error
set -e

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Install zfs
apt-get install -y zfsutils-linux

# Show disk list
lsblk

# Ask which disks to use
echo "Enter the disks to use (e.g. sda sdb sdc):"
read -r disks
DISK_NUM=$(echo "$disks" | wc -w)
IFS=' ' read -r -a disks <<< "$disks"

# DISK_NUM must be even
if [ $((DISK_NUM)) -ne 4 ]; then
  echo "Currently only 4 disks are supported"
  exit
fi

# Clear the disks
for disk in "${disks[@]}"; do
  wipefs -a "/dev/$disk"
done

# Create pool
zpool create -m /public/Storage mirror ${disks[0]} ${disks[1]} mirror ${disks[2]} ${disks[3]} -f
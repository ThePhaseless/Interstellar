#!/bin/bash

# Exit immediately if any command fails
set -e


# Check if STORAGE_PATH is set
if [ -z "$STORAGE_PATH" ]; then
	echo "STORAGE_PATH = $STORAGE_PATH"
	echo "STORAGE_PATH not set..."
	# Ask for STORAGE path, if empty set to /public/STORAGE
	echo "Where should the STORAGE be mounted? (e.g., /public/Storage)"
	read -r -p "STORAGE path: " STORAGE_PATH
	if [ -z "$STORAGE_PATH" ]; then
		echo "STORAGE_PATH not set, skipping STORAGE setup..."
		exit 0
	# Check if STORAGE_PATH exists
	elif [ ! -d "$STORAGE_PATH" ]; then
		echo "STORAGE_PATH does not exist..."
		exit 1
	fi
fi

if [ -z "${DISKS[*]}" ]; then
	lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT
	echo "Which disks should be used with STORAGE? RAID10 requires at least 4 disks. (e.g. sdb sdc sdd sde)"
	read -r -p "Disks: " DISKSRAW
	if [ "$DISKS" = "none" ]; then
		echo "Skipping STORAGE setup..."
		exit 0
	fi
	# Split disks into array
	IFS=' ' read -r -a DISKS <<< "$DISKSRAW"
fi

# Check if disks are specified
if [ -z "${DISKS[*]}" ]; then
	echo "No disks specified..."
	exit 1
fi

# Check if 4 disks are specified
if [ "${#DISKS[@]}" -lt 4 ]; then
	echo "RAID10 requires at least 4 disks..."
	exit 1
fi

# Install mdadm
sudo apt update
sudo apt install mdadm -y

# Check drives
echo "Checking disks..."
set +e
for i in "${!DISKS[@]}"; do
	DISK="${DISKS[$i]}"

	# Check if disk exists
	if [ ! -e "/dev/${DISK}" ]; then
		echo "Disk /dev/${DISK} does not exist..."
		exit 1
	fi

	# Check if disk is mounted
	if grep -qs "/dev/${DISK}" /proc/mounts; then
		echo "Disk /dev/${DISK} is mounted..."
		exit 1
	fi

	# Add /dev/ to disks
	DISKS[i]="/dev/${DISK}"
done
set -e

# Get disk count
DISKCOUNT="${#DISKS[@]}"

# Create RAID10
sudo mdadm --create --verbose /dev/md0 --level=10 --raid-devices="$DISKCOUNT" "${DISKS[@]}"

# Create filesystem
echo "Creating filesystem..."
sudo mkfs.ext4 -F /dev/md0

# Mount STORAGE
echo "Mounting STORAGE..."
sudo mount /dev/md0 "$STORAGE_PATH"

# Check if STORAGE config is already in fstab
if sudo grep -q "# STORAGE" /etc/fstab; then
	echo "STORAGE already in fstab..."
	echo "Removing old STORAGE from fstab..."
	# Remove old STORAGE from fstab
	sudo sed -i '/# STORAGE/,/# STORAGE END/d' /etc/fstab
fi

echo "Adding STORAGE to fstab..."
# Find UUID of STORAGE
echo "Finding UUID of STORAGE..."
STORAGE_UUID=$(blkid -s UUID -o value /dev/md0)
echo "UUID of STORAGE: $STORAGE_UUID"

# Add STORAGE to fstab
echo "Adding STORAGE to fstab..."
echo "# STORAGE" | sudo tee -a /etc/fstab
echo "# DO NOT EDIT THIS SECTION BY HAND" | sudo tee -a /etc/fstab
echo "UUID=$STORAGE_UUID $STORAGE_PATH ext4 defaults,nofail,discard 0 0" | sudo tee -a /etc/fstab
echo "# STORAGE END" | sudo tee -a /etc/fstab

# Update initramfs
echo "Updating initramfs..."
sudo update-initramfs -u

echo "Done..."

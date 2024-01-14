#!/bin/bash

# Check if STORAGE_PATH is set
if [ -z "$STORAGE_PATH" ]; then
	echo "STORAGE_PATH = $STORAGE_PATH"
	echo "STORAGE_PATH not set..."
	# Ask for STORAGE path, if empty set to /public/STORAGE
	echo "Where should the STORAGE be mounted? (e.g., /public/STORAGE)"
	read -r -p "STORAGE path: " STORAGE_PATH
	if [ -z "$STORAGE_PATH" ]; then
		echo "STORAGE_PATH not set, skipping STORAGE setup..."
		exit 0
	fi
fi

lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT
echo "Which disks should be used with STORAGE? RAID10 requires at least 4 disks. (e.g. sdb sdc sdd sde)"
read -r -p "Disks: " DISKS
if [ "$DISKS" = "none" ]; then
	echo "Skipping STORAGE setup..."
	exit 0
fi

# Check if disks are specified
if [ -z "$DISKS" ]; then
	echo "No disks specified..."
	exit 1
fi

# Check if 4 disks are specified
if [ "$(echo "$DISKS" | wc -w)" -lt 4 ]; then
	echo "RAID10 requires at least 4 disks..."
	exit 1
fi

# Install mdadm
sudo apt update
sudo apt install mdadm -y

# Check drives
echo "Checking disks..."
for DISK in $DISKS; do
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
done

# Create pairs of RAID1
echo "Creating RAIDs1..."
RAIDnum=1
RAID1Arrays=""
tempDisks=""
for DISK in $DISKS; do
	# Add disk to tempDisks
	tempDisks="$tempDisks /dev/${DISK}"

	# Check if 2 disks are in tempDisks
	if [ "$(echo "$tempDisks" | wc -w)" -eq 2 ]; then
		# Create RAID1
		echo "Creating RAID1 with $tempDisks..."
		mdadm --create --verbose /dev/md$RAIDnum --level=1 --raid-devices=2 "$tempDisks"

		# Add RAID1 to mdadm.conf
		echo "Adding RAID1 to mdadm.conf..."
		mdadm --detail --scan | tee -a /etc/mdadm/mdadm.conf

		# Add RAID1 to mdadm.conf
		echo "Adding RAID1 to mdadm.conf..."
		mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf

		# Add RAID1 to RAID1Arrays
		RAID1Arrays="$RAID1Arrays /dev/md$RAIDnum"

		# Increase disknum
		RAIDnum=$((RAIDnum + 1))

		# Reset tempDisks
		tempDisks=""
	fi
done

# Create RAID10
echo "Creating RAID10 with $RAID1Arrays..."
mdadm --create --verbose /dev/md0 --level=10 --raid-devices=4 "$RAID1Arrays"

# Create filesystem
echo "Creating filesystem..."
mkfs.ext4 -F /dev/md0

# Mount STORAGE
echo "Mounting STORAGE..."
mkdir -p "$STORAGE_PATH"
mount /dev/md0 "$STORAGE_PATH"

# Check if STORAGE config is already in fstab
if grep -q "# STORAGE" /etc/fstab; then
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
echo "# STORAGE" | tee -a /etc/fstab
echo "# DO NOT EDIT THIS SECTION BY HAND" | tee -a /etc/fstab
echo "UUID=$STORAGE_UUID $STORAGE_PATH ext4 defaults,nofail,discard 0 0" | tee -a /etc/fstab
echo "# STORAGE END" | tee -a /etc/fstab

# Update initramfs
echo "Updating initramfs..."
sudo update-initramfs -u

echo "Done..."

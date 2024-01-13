#!/bin/bash
#
# Create MergerFS Script
# ----------------------

# Check if using root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Check if mergerfs is installed
if ! command -v mergerfs &>/dev/null; then
    echo "mergerfs is not installed"
    echo "Do you want to install mergerfs? (Y/n)"
    read -r -p "Answer: " answer
    case $answer in
    [Nn] | no) echo "Canceling..." && exit 1 ;;
    *)
        # Ask user for link for mergerfs
        echo "Please provide a link to the mergerfs deb file"
        read -r -p "Link: " link

        # Download mergerfs
        echo "Downloading mergerfs..."
        wget -O mergerfs.deb "$link"

        # Install mergerfs
        echo "Installing mergerfs..."
        dpkg -i mergerfs.deb

        # Remove mergerfs.deb
        echo "Removing mergerfs.deb..."
        rm mergerfs.deb
        ;;
    esac
fi

# Check if disks are valid
if [ -z "$JBOD_PATH" ]; then
    echo "JBOD_PATH = $JBOD_PATH"
    echo "JBOD_PATH not set..."
    echo "Do you want to set JBOD_PATH to /public/HDD? (y/N)"
    read -r -p "Answer: " answer
    case $answer in
    [Yy] | yes)
        export JBOD_PATH="/public/HDD"
        ;;
    *) echo "Canceling..." && exit 1 ;;
    esac
fi

# Create JBOD_PATH
mkdir -p "$JBOD_PATH"

# Show disks
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT

# Ask for disks
echo "Which disks should be used with MergerFS? (e.g., sda sdb sdc, sdc sdd1, sda1 sdc3, none)"
read -r -p "Disks: " DISKS

# Check if disks are specified
if [ -z "$DISKS" ]; then
    echo "No disks specified..."
    exit 1
fi

# Check if disks are none
if [ "$DISKS" == "none" ]; then
    echo "Canceling..."
    exit 1
fi

# Start setting up MergerFS
echo "Setting up MergerFS..."
MergerFS_disks_num=0
MergerFS_disks=""
for DISK in $DISKS; do
    # Check if disk exists
    if [ ! -e "/dev/$DISK" ]; then
        echo "Disk /dev/$DISK does not exist..."
        exit 1
    fi

    # Check if disk is mounted
    if grep -qs "/dev/$DISK" /proc/mounts; then
        echo "Disk /dev/$DISK is mounted..."
        exit 1
    fi

    # Check if last character is a number (partition)
    if [[ "${DISK:(-1)}" =~ ^[0-9]+$ ]]; then
        echo "Disk /dev/$DISK is a partition..."
        echo "Getting partition UUID..."
        uuid=$(blkid -s UUID -o value /dev/"$DISK")
        if [ -z "$uuid" ]; then
            echo "UUID not found..."
            exit 1
        fi
    else
        echo "Disk /dev/$DISK is not a partition..."
        # Ask user if he wants to format the disk
        read -r -p "Do you want to format and create a new and only partition on /dev/$DISK? (y/N) " answer
        case $answer in
        [Yy]*)
            # Remove all partitions
            echo "Removing existing partitions..."
            wipefs -a /dev/"$DISK"

            # Create partition
            echo "Creating partition..."
            parted -s /dev/"$DISK" mklabel gpt mkpart primary ext4 0% 100%
            sleep 1

            # Format partition
            echo "Formatting partition..."
            mkfs.ext4 -F /dev/"$DISK"\1

            # Get partition UUID
            uuid=$(blkid -s UUID -o value /dev/"$DISK""1")

            # Check if UUID is empty
            if [ -z "$uuid" ]; then
                echo "UUID not found..."
                exit 1
            fi
            ;;
        *) echo "Canceling..." && exit 1 ;;
        esac
    fi

    # Mount disk
    mkdir -p /mnt/disk$MergerFS_disks_num
    mount UUID="$uuid" /mnt/disk$MergerFS_disks_num

    # Check if disk exists in fstab
    if grep -q "/dev/$DISK" /etc/fstab; then
        echo "Disk /dev/$DISK already in fstab..."
    else
        echo "Adding disk /dev/$DISK to fstab..."
        echo "UUID=$uuid /mnt/disk$MergerFS_disks_num ext4 defaults 0 0" | tee -a /etc/fstab
    fi

    # Add disk to MergerFS
    MergerFS_disks="$MergerFS_disks /dev/$DISK"
    MergerFS_disks_num=$((MergerFS_disks_num + 1))
done

# Create MergerFS
mergerfs_options="defaults,nonempty,cache.files=partial,moveonenospc=true,category.create=mfs,dropcacheonclose=true,fsname=mergerfs"

# If without --test then add to fstab
if [ "$1" != "--test" ]; then
    # Check if MergerFS is already in fstab
    if grep -q "$JBOD_PATH" /etc/fstab; then
        echo "MergerFS already in fstab..."
    else
        echo "Adding MergerFS to fstab..."
        # Add MergerFS to fstab
        echo "/mnt/disk* $JBOD_PATH fuse.mergerfs $mergerfs_options 0 0" | tee -a /etc/fstab
        # Update initramfs
        echo "Updating initramfs..."
        systemctl daemon-reload
    fi
fi

# Applying mounts
echo "Applying mounts..."
mount -a
echo "Done..."

lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT
echo "Which disks should be used with JBOD? (e.g., sda sdb sdc, none)"
read -r -p "Disks: " DISKS
if [ "$DISKS" = "none" ]; then
    echo "Skipping JBOD setup..."
else
    # Check if disks are specified
    if [ -z "$DISKS" ]; then
        echo "No disks specified..."
        exit 1
    fi

    # Check if disks are valid
    if [ -z "$JBOD_PATH" ]; then

        echo "JBOD_PATH = $JBOD_PATH"
        echo "JBOD_PATH not set..."
        # Ask for JBOD path, if empty set to /public/HDD
        echo "Where should the JBOD be mounted? (e.g., /public/HDD)"
        read -r -p "JBOD path: " JBOD_PATH
        if [ -z "$JBOD_PATH" ]; then
            JBOD_PATH="/public/HDD"
        fi
    fi

    echo "Setting up JBOD..."
    JBOD_disks_num=0
    JBOD_disks=""
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

        # Check if last character is a number (partition)
        if [[ "${DISK:(-1)}" =~ ^[0-9]+$ ]]; then
            echo "Disk /dev/${DISK} is a partition..."
            echo "Adding to JBOD..."
            JBOD_disks="$JBOD_disks /dev/${DISK}"
        else
            # Remove all partitions
            echo "Removing existing partitions from /dev/${DISK}..."
            wipefs -a /dev/"${DISK}"

            # Create partition
            echo "Creating partition..."
            parted -s /dev/"${DISK}" mklabel gpt mkpart primary ext4 0% 100%
            sleep 1

            # Add partition to JBOD
            echo "Adding to JBOD..."
            JBOD_disks="$JBOD_disks /dev/${DISK}1"
        fi
        JBOD_disks_num=$((JBOD_disks_num + 1))
    done

    # Create JBOD
    echo "Creating RAID0..."
    mdadm --create --verbose /dev/md0 --level=0 --raid-devices=$JBOD_disks_num "$JBOD_disks"

    # Create filesystem
    echo "Creating filesystem..."
    mkfs.ext4 -F /dev/md0

    # Mount JBOD
    echo "Mounting JBOD..."
    mkdir -p "$JBOD_PATH"
    mount /dev/md0 "$JBOD_PATH"

    # Check if JBOD config is already in fstab
    if grep -q "# JBOD" /etc/fstab; then
        echo "JBOD already in fstab..."
        echo "Removing old JBOD from fstab..."
        # Remove old JBOD from fstab
        sudo sed -i '/# JBOD/,/# JBOD END/d' /etc/fstab
    fi

    echo "Adding JBOD to fstab..."
    # Find UUID of JBOD
    echo "Finding UUID of JBOD..."
    JBOD_UUID=$(blkid -s UUID -o value /dev/md0)
    echo "UUID of JBOD: $JBOD_UUID"

    # Add JBOD to fstab
    echo "Adding JBOD to fstab..."
    echo "# JBOD" | tee -a /etc/fstab
    echo "# DO NOT EDIT THIS SECTION BY HAND" | tee -a /etc/fstab
    echo "UUID=$JBOD_UUID $JBOD_PATH ext4 defaults,nofail,discard 0 0" | tee -a /etc/fstab
    echo "# JBOD END" | tee -a /etc/fstab

    # Update initramfs
    echo "Updating initramfs..."
    sudo update-initramfs -u

    echo "Done..."
fi

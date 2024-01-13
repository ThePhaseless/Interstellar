# Exit immediately if any command fails
set -e

# Function to set permissions and ownership
set_permissions_ownership() {
	sudo chmod 755 "$1" -R
	sudo chown nobody:nogroup "$1" -R
}

# Set default values for environment variables from fireword.env
echo "Using these environment variables:"
if [ -f "$PWD"/.env ]; then
	echo "Using environment variables from $PWD/.env"
	source "$PWD"/.env
else
	echo "No ./host/fireword.env file found, please set them and run the script again."
	exit
fi

# Ask the user if the default environment variables should be used
read -r -p "Continue? (Y/n): " answer
case ${answer,,} in
n*)
	echo "Please set the environment variables and run the script again."
	exit
	;;
esac

# Apply sudo patch
./Scripts/setup_sudo_patch.sh

# Create directories
echo "Creating directories..."
for directory in "$CONFIG_PATH" "$MEDIA_PATH" "$SSD_PATH" "$JBOD_PATH"; do
	echo "Creating $directory"
	sudo mkdir -p "$directory"
	set_permissions_ownership "$directory"
done
echo "Done."

# Set up Timezone
echo "Setting up Timezone..."
sudo timedatectl set-timezone "$TIMEZONE"
echo "Timezone set."

# Update the package list and upgrade existing packages
echo "Updating system..."
sudo apt update
sudo apt fully-upgrade
sudo apt dist-upgrade
sudo unattended-upgrades
sudo fwupdmgr refresh
sudo fwupdmgr update

# Ask if the user wants to make a JBOD with raid0 or mergerfs or none
echo "Do you want to setup a disk array?"
echo "1) RAID0"
echo "2) MergerFS"
echo "other) None"
read -r -p "Choice: " choice
case $choice in
[1]*)
	sudo bash ./Scripts/setup_RAID0.sh
	;;
[2]*)
	sudo bash ./Scripts/setup_mergerfs.sh
	;;
*)
	echo "Skipping..."
	;;
esac

# Install Zsh and Oh-My-Zsh
## For user
./Scripts/setup_zsh.sh

## For root
sudo ./Scripts/setup_zsh.sh

# Create global environment variables
env_vars="
export CONFIG_PATH=$CONFIG_PATH\n
export MEDIA_PATH=$MEDIA_PATH\n
export SSD_PATH=$SSD_PATH\n
export JBOD_PATH=$JBOD_PATH\n
"

## For bash
echo "Creating global environment variables..."
if [ -f /etc/profile.d/litwave.sh ]; then
	sudo rm /etc/profile.d/litwave.sh
fi
sudo touch /etc/profile.d/litwave.sh
echo -e "$env_vars" >>/etc/environment.d/litwave.sh

## For zsh
if [ -f /etc/zsh/zshenv ]; then
	sudo rm /etc/zsh/zprofile
fi

./Scripts/update_traefik_conf.sh
./Scripts/update_proxy_stack.sh

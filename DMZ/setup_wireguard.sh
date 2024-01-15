#!/bin/bash
# Stop on error
set -e

echo "Settings up Wireguard for DMZ..."
sudo apt update
sudo apt install wireguard -y

generateNewKeys=false
# check if keys are already generated
if [ -f "./privatekey" ] && [ -f "./publickey" ]; then
	echo "Found existing Wireguard key pair..."
	read -r -p "Do you want to generate a new key pair? [y/N] " response
	if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
		generateNewKeys=true
	fi
elif [ ! -f "./privatekey" ] && [ ! -f "./publickey" ]; then
	echo "No Wireguard key pair found, generating a new one..."
	generateNewKeys=true
else
	echo "Found incomplete Wireguard key pair, generating a new one..."
	generateNewKeys=true
fi

if [ "$generateNewKeys" = true ]; then
	# Generate a key pair for Wireguard
	echo "Generating Wireguard key pair..."
	wg genkey | tee ./privatekey | wg pubkey | tee ./publickey
fi
echo "Public key: $(cat ./publickey)"
echo "Please note down the public key. You will need it later to set up client."
echo "Now run setup on the VPS and press enter after you get the public key of the VPS."
read -r -p "Press enter to continue: "
if [ ! -f "./wireguard.env" ]; then
	echo "No wireguard.env file found, creating one..."
	cp ./wireguard.env.example ./wireguard.env
fi
nano ./wireguard.env
source ./wireguard.env

# Ask if user wants to continue
read -r -p "Do you want to continue? [Y/n] " response
if [[ "$response" =~ ^([nN][oO]|[nN])+$ ]]; then
echo "Exiting..."
	exit 0
fi

# Install Wireguard
sudo apt install software-properties-common
sudo apt install wireguard -y

# Configure Wireguard
sudo rm -f /etc/wireguard/wg0.conf
(umask 077 && printf "[Interface]\nPrivateKey = " | sudo tee /etc/wireguard/wg0.conf >/dev/null)
sudo cat ./privatekey | sudo tee -a /etc/wireguard/wg0.conf >/dev/null
append="Address = $WIREGUARD_DMZ_IP/32

[Peer]
PublicKey = $WIREGUARD_VPS_PUBLIC_KEY
AllowedIPs = $WIREGUARD_VPS_IP/32
Endpoint = $VPS_PUBLIC_IP:$WIREGUARD_PORT
PersistentKeepalive = 25"

# Add the following to the end of the file
echo "$append" | sudo tee -a /etc/wireguard/wg0.conf >/dev/null

# Convert DOS to UNIX format
sudo sed -i 's/\r$//' /etc/wireguard/wg0.conf

# Disable old configuration
sudo systemctl disable wg-quick@wg0
sudo systemctl stop wg-quick@wg0

# Uncomment net.ipv4.ip_forward=1
echo "Uncommenting net.ipv4.ip_forward=1..."
sudo sed -i '/net.ipv4.ip_forward=1/s/^#//g' /etc/sysctl.conf
sudo sysctl --system


# Enable Wireguard
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Wait untill wireguard is up
echo "Waiting for Wireguard to come up..."
while ! ping -c 1 -W 1 "$WIREGUARD_VPS_IP"; do
	sleep 1
done

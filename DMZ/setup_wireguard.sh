#!/bin/bash
# Stop on error
set -e

echo "Settings up Wireguard for DMZ..."

# Generate a key pair for Wireguard
echo "Generating Wireguard key pair..."
wg genkey | tee ./privatekey | wg pubkey | tee ./publickey
echo "Public key: $(cat ./publickey)"
echo "Please note down the public key. You will need it later to set up client."
echo "Now run setup on the VPS and press enter after you get the public key of the VPS."
read -r -p "Press enter to continue: "
if [ ! -f "./.env" ]; then
	echo "No wireguard.env file found, creating one..."
	cp ./wireguard.env.example ./wireguard.env
fi
nano ./wireguard.env
source ./wireguard.env

# Ask if user wants to continue
read -r -p "Do you want to continue? [y/N] " response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
	echo "Aborting..."
	exit 1
fi

# Install Wireguard
sudo apt install software-properties-common
sudo apt install wireguard -y

# Configure Wireguard
sudo rm -f /etc/wireguard/wg0.conf
(umask 077 && printf "[Interface]\nPrivateKey = " | sudo tee /etc/wireguard/wg0.conf >/dev/null)
sudo cat ./privatekey | sudo tee -a /etc/wireguard/wg0.conf >/dev/null
append="\
Address = $WIREGUARD_DMZ_IP/32

[Peer]
PublicKey = $WIREGUARD_DMZ_PUBLIC_KEY
AllowedIPs = $WIREGUARD_VPS_IP/32
Endpoint = $VPS_PUBLIC_IP:$WIREGUARD_PORT
PersistentKeepalive = 25"

# Add the following to the end of the file
$append | sudo tee -a /etc/wireguard/wg0.conf >/dev/null

# Enable Wireguard
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Test connection
echo "Testing connection..."
ping "$WIREGUARD_DMZ_IP"
echo "If you see a response, the connection is working."
echo "If you don't see a response, check the configuration and try again."
echo "If you still don't see a response, check the firewall rules and try again."

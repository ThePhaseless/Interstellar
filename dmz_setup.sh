#!/bin/bash
# Stop on error
set -e

# Check if .env file exists
if [ ! -f "./.env" ]; then
    echo "No .env file found, creating one..."
    cp ./.env.example ./.env
fi
nano ./.env

# Set default values
WIREGUARD_PORT=51820
WIREGUARD_DMZ_IP=192.168.5.2
WIREGUARD_VPS_IP=192.168.5.1
KEYS_LOCATION=./keys
VPN_INTERFACE=wg0

# Source the .env file
source ./.env

echo "Settings up Wireguard for DMZ..."
sudo apt update
sudo apt install wireguard -y

generateNewKeys=false
# check if keys are already generated
if [ ! -f "$KEYS_LOCATION/dmz.pem" ] || [ ! -f "$KEYS_LOCATION/dmz.pub" ]; then
    echo "Could not find existing key pair in $KEYS_LOCATION"
    generateNewKeys=true
else
    echo "Found existing key pair in $KEYS_LOCATION..."
    read -r -p "Do you want to generate a new key pair? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        generateNewKeys=true
    else
        echo "Using existing key pair..."
    fi
fi

if [ "$generateNewKeys" = true ]; then
    # Generate a key pair for Wireguard
    echo "Generating Wireguard key pair..."
    mkdir -p "$KEYS_LOCATION"
    wg genkey | tee "$KEYS_LOCATION/dmz.pem" | wg pubkey | tee "$KEYS_LOCATION/dmz.pub"
fi
echo "Public key: $(cat "$KEYS_LOCATION/dmz.pub")"
echo "Please note down the public key. You will need it later to set up client."

# Setting up vps public key
echo "Now run setup on the VPS and press enter after you get the public key of the VPS."
read -r -p "Press enter to continue: "
echo "Opening key $KEYS_LOCATION/vps.pub..."
nano "$KEYS_LOCATION/vps.pub"
read -r -p "Press enter to continue: "

# Build Wireguard config
echo "Building Wireguard config..."
if [ -f "/etc/wireguard/$VPN_INTERFACE.conf" ]; then
    read -r -p "Wireguard config already exists. Do you want to overwrite it? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        echo "Overwriting existing config..."
        sudo wg-quick down $VPN_INTERFACE
        rm /etc/wireguard/$VPN_INTERFACE.conf
    else
        echo "Exiting..."
        exit 0
    fi
fi
config="[Interface]
PrivateKey = $(cat "$KEYS_LOCATION/dmz.pem")
Address = $WIREGUARD_VPS_IP/24
ListenPort = $WIREGUARD_PORT

[Peer]
PublicKey = $(cat "$KEYS_LOCATION/vps.pub")
AllowedIPs = $WIREGUARD_VPS_IP/32
Endpoint = $PUBLIC_VPS_IP:$WIREGUARD_PORT
PersistentKeepalive = 25"

sudo touch /etc/wireguard/$VPN_INTERFACE.conf
sudo chmod 777 /etc/wireguard/$VPN_INTERFACE.conf
echo "$config" | sudo tee /etc/wireguard/$VPN_INTERFACE.conf

# Allow iptables forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo wg-quick up $VPN_INTERFACE

# Test connection
echo "Testing connection..."
while true; do
    sleep 1
    if ping -c 1 -W 1 $WIREGUARD_DMZ_IP; then
        break
    fi
done
echo "Connection successful!"
sudo systemctl enable wg-quick@$VPN_INTERFACE

# Speed test connection
echo "Speed testing connection..."
sudo apt install iperf3 -y
sleep 5
iperf3 -c $WIREGUARD_DMZ_IP

echo "Done!"
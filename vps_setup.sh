#!/bin/bash
# Stop on error
set -e

# Check if .env file exists
if [ ! -f "./.env" ]; then
    echo "No .env file found, creating one..."
    if [ ! -f "./.env.example" ]; then
        echo "No .env.example file found, exiting..."
        exit 1
    fi
    cp ./.env.example ./.env
fi
nano ./.env

# Set default values
WIREGUARD_PORT=51820
WIREGUARD_DMZ_IP=192.168.5.2
WIREGUARD_VPS_IP=192.168.5.1
VPN_INTERFACE=wg0
KEYS_LOCATION=./keys
REDIRECT_PORTS=443,80

# Source the .env file
source ./.env

# Transform ports to array
IFS=',' read -r -a REDIRECT_PORTS <<< "$REDIRECT_PORTS"

echo "Settings up Wireguard for DMZ..."
sudo apt update
sudo apt install wireguard -y

generateNewKeys=false
# Check if keys are already generated
if [ ! -f "$KEYS_LOCATION/vps.pem" ] || [ ! -f "$KEYS_LOCATION/vps.pub" ]; then
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

# Generate a key pair for Wireguard
if [ "$generateNewKeys" = true ]; then
    # Generate a key pair for Wireguard
    echo "Generating Wireguard key pair..."
    mkdir -p "$KEYS_LOCATION"
    wg genkey | tee "$KEYS_LOCATION/vps.pem" | wg pubkey | tee "$KEYS_LOCATION/vps.pub"
fi
echo "Public key $KEYS_LOCATION/vps.pub:"
cat "$KEYS_LOCATION/vps.pub"
echo "Please note down the public key. You will need it later to set up client."

# Setting up dmz public key
echo "Now run setup on the VPS and press enter after you get the public key of the VPS."
read -r -p "Press enter to continue: "
echo "Opening key $KEYS_LOCATION/dmz.pub..."
nano "$KEYS_LOCATION/dmz.pub"
read -r -p "Press enter to continue: "

# Build Wireguard config
echo "Building Wireguard config..."
sudo chmod 777 /etc/wireguard -R
if [ -f "/etc/wireguard/$VPN_INTERFACE.conf" ]; then
    read -r -p "Wireguard config already exists. Do you want to overwrite it? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        echo "Overwriting existing config..."
        sudo wg-quick down $VPN_INTERFACE
        sudo rm -f /etc/wireguard/$VPN_INTERFACE.conf
    else
        echo "Using existing config..."
        exit 0
    fi
fi

config="[Interface]
PrivateKey = $(cat "$KEYS_LOCATION/vps.pem")
Address = $WIREGUARD_VPS_IP/24
ListenPort = $WIREGUARD_PORT

[Peer]
PublicKey = $(cat "$KEYS_LOCATION/dmz.pub")
AllowedIPs = $WIREGUARD_DMZ_IP/32"
echo "$config" > /etc/wireguard/$VPN_INTERFACE.conf

sudo wg-quick up $VPN_INTERFACE

# Check connection
echo "Checking connection..."
while true; do
    sleep 1
    if ping -c 1 -W 1 $WIREGUARD_DMZ_IP; then
        break
    fi
done
echo "Connection successful!"

# Redirect ports with nginx
echo "Redirecting ports..."
sudo apt install nginx -y
nginx_config="stream {"
for port in "${REDIRECT_PORTS[@]}"; do
    nginx_config="$nginx_config
    server {
        listen $port;
        proxy_pass $WIREGUARD_DMZ_IP;
    }"
done
nginx_config="$nginx_config
}"

if [ -f "/etc/nginx/modules-enabled/proxy.conf" ]; then
    sudo rm /etc/nginx/modules-enabled/proxy.conf
fi
sudo chmod 777 /etc/nginx/modules-enabled
echo "$nginx_config" > /etc/nginx/modules-enabled/proxy.conf

sudo systemctl restart nginx
sudo systemctl enable nginx
echo "Done!"
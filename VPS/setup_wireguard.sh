#!/bin/bash
# Stop on error
set -e

echo "Installing Wireguard for VPS..."
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
echo "Now run setup on the DMZ and press enter after you get the public key of the DMZ."
read -r -p "Press enter to continue: "
if [ ! -f "./.env" ]; then
	echo "No .env file found, creating one..."
	cp ./.env.example ./.env
fi
nano ./.env
source ./.env

# Install Wireguard
sudo apt install software-properties-common
sudo apt install wireguard -y

# Configure Wireguard
sudo rm -f /etc/wireguard/wg0.conf
(umask 077 && printf "[Interface]\nPrivateKey = " | sudo tee /etc/wireguard/wg0.conf >/dev/null)
sudo cat ./privatekey | sudo tee -a /etc/wireguard/wg0.conf >/dev/null
append="ListenPort = $WIREGUARD_PORT
Address = $WIREGUARD_VPS_IP/24

[Peer]
PublicKey = $WIREGUARD_DMZ_PUBLIC_KEY
AllowedIPs = $WIREGUARD_DMZ_IP/32"

# Add the following to the end of the file
echo "$append" | sudo tee -a /etc/wireguard/wg0.conf >/dev/null

# Disable old configuration
sudo systemctl disable wg-quick@wg0
sudo systemctl stop wg-quick@wg0

# Enable Wireguard
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Ask user to press enter after setting up the DMZ
read -r -p "Press enter after setting up the DMZ..."

# Configure UFW
echo "Configuring firewall..."
## Check which interface is the default
default_interface=$(ip route | grep default | head -n 1 | awk '{print $5}')
echo "Default interface: $default_interface"

## Remove old rules with comment "VPS to DMZ" and "DMZ to VPS"
echo "Removing old rules..."
comment1="DMZ to VPS"
comment2="VPS to DMZ"

sudo iptables-save | grep -v COMMENT | sudo iptables-restore

echo "Rules with comments '$comment1' or '$comment2' have been removed."

# Uncomment net.ipv4.ip_forward=1
echo "Uncommenting net.ipv4.ip_forward=1..."
sudo sed -i '/net.ipv4.ip_forward=1/s/^#//g' /etc/sysctl.conf
sudo sysctl --system


## Create a new iptables chain and set the default rules to DROP
echo "Creating new iptables profile..."
sudo iptables -P FORWARD DROP -m comment --comment "VPS to DMZ"
sudo iptables -I INPUT -p udp --dport 51820 -j ACCEPT -m comment --comment "Wireguard"

## Allow forwarding from the default interface to the Wireguard interface on ports 80 and 443
echo "Allowing forwarding from the default interface to the Wireguard interface on ports 80 and 443..."
sudo iptables -A FORWARD -i "$default_interface" -o wg0 -p tcp --syn --dport 80 -m conntrack --ctstate NEW -j ACCEPT -m comment --comment "VPS to DMZ"
sudo iptables -A FORWARD -i "$default_interface" -o wg0 -p tcp --syn --dport 443 -m conntrack --ctstate NEW -j ACCEPT -m comment --comment "VPS to DMZ"

## Allow established and related connections to pass through
echo "Allowing established and related connections to pass through..."
sudo iptables -A FORWARD -i "$default_interface" -o wg0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT -m comment --comment "VPS to DMZ"
sudo iptables -A FORWARD -i wg0 -o "$default_interface" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT -m comment --comment "DMZ to VPS"

## Redirect traffic from the default interface to the Wireguard interface on ports 80 and 443 to the DMZ
echo "Redirecting traffic from the default interface to the Wireguard interface on ports 80 and 443 to the DMZ..."
sudo iptables -t nat -A PREROUTING -i "$default_interface" -p tcp --dport 80 -j DNAT --to-destination "$WIREGUARD_DMZ_IP" -m comment --comment "VPS to DMZ"
sudo iptables -t nat -A PREROUTING -i "$default_interface" -p tcp --dport 443 -j DNAT --to-destination "$WIREGUARD_DMZ_IP" -m comment --comment "VPS to DMZ"

## Redirect returning traffic from the Wireguard interface to the default interface on ports 80 and 443
echo "Redirecting returning traffic from the Wireguard interface to the default interface on ports 80 and 443..."
sudo iptables -t nat -A POSTROUTING -o wg0 -p tcp --dport 80 -d "$WIREGUARD_DMZ_IP" -j SNAT --to-source "$WIREGUARD_VPS_IP" -m comment --comment "DMZ to VPS"
sudo iptables -t nat -A POSTROUTING -o wg0 -p tcp --dport 443 -d "$WIREGUARD_DMZ_IP" -j SNAT --to-source "$WIREGUARD_VPS_IP" -m comment --comment "DMZ to VPS"

## Save the rules
echo "Saving the rules..."
sudo apt install netfilter-persistent -y
sudo netfilter-persistent save
sudo apt install iptables-persistent -y
sudo systemctl enable netfilter-persistent
sudo apt install iptables-persistent


## Enable UFW
echo "Enabling UFW..."
sudo ufw allow 22  # SSH
sudo ufw allow 80  # HTTP
sudo ufw allow 443 # HTTPS
sudo ufw allow "$WIREGUARD_PORT"/udp

# Wait untill wireguard is up
echo "Waiting for Wireguard to come up..."
while ! ping -c 1 -W 1 "$WIREGUARD_DMZ_IP"; do
	echo "Waiting for Wireguard to come up..."
	sleep 1
done
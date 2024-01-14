#!/bin/bash
# Stop on error
set -e

echo "Installing Wireguard for VPS..."

# Generate a key pair for Wireguard
echo "Generating Wireguard key pair..."
wg genkey | tee ./privatekey | wg pubkey | tee ./publickey
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
append="\
ListenPort = $WIREGUARD_PORT
Address = $WIREGUARD_VPS_IP/24

[Peer]
PublicKey = $WIREGUARD_DMZ_PUBLIC_KEY
AllowedIPs = $WIREGUARD_DMZ_IP/32"

# Add the following to the end of the file
$append | sudo tee -a /etc/wireguard/wg0.conf >/dev/null

# Enable Wireguard
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Configure UFW
echo "Configuring firewall..."
## Check which interface is the default
default_interface=$(ip route | grep default | awk '{print $5}')

## Create a new UFW profile and set the default rules to DROP
sudo iptables -P FORWARD DROP

## Allow forwarding from the default interface to the Wireguard interface on ports 80 and 443
sudo iptables -A FORWARD -i "$default_interface" -o wg0 -p tcp --syn --dport 80 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A FORWARD -i "$default_interface" -o wg0 -p tcp --syn --dport 443 -m conntrack --ctstate NEW -j ACCEPT

## Allow established and related connections to pass through
sudo iptables -A FORWARD -i "$default_interface" -o wg0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o "$default_interface" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

## Redirect traffic from the default interface to the Wireguard interface on ports 80 and 443 to the DMZ
sudo iptables -t nat -A PREROUTING -i "$default_interface" -p tcp --dport 80 -j DNAT --to-destination $WIREGUARD_DMZ_IP
sudo iptables -t nat -A PREROUTING -i "$default_interface" -p tcp --dport 443 -j DNAT --to-destination $WIREGUARD_DMZ_IP

## Redirect returning traffic from the Wireguard interface to the default interface on ports 80 and 443
sudo iptables -t nat -A POSTROUTING -o wg0 -p tcp --dport 80 -d $WIREGUARD_DMZ_IP -j SNAT --to-source $WIREGUARD_VPS_IP
sudo iptables -t nat -A POSTROUTING -o wg0 -p tcp --dport 443 -d $WIREGUARD_DMZ_IP -j SNAT --to-source $WIREGUARD_VPS_IP

## Save the rules
sudo apt install netfilter-persistent -y
sudo netfilter-persistent save
sudo apt install iptables-persistent -y
sudo systemctl enable netfilter-persistent
sudo apt install iptables-persistent

## Enable UFW
sudo ufw allow 22  # SSH
sudo ufw allow 80  # HTTP
sudo ufw allow 443 # HTTPS
sudo ufw allow "$WIREGUARD_PORT"/udp

# Test the connection
echo "Testing the connection..."
ping "$WIREGUARD_DMZ_IP"
echo "If you see a response, the connection is working."
echo "If you don't see a response, check the configuration and try again."
echo "If you still don't see a response, check the firewall rules and try again."

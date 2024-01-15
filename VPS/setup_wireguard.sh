#!/bin/bash
# Stop on error
set -e

echo "Installing Wireguard for VPS..."
sudo apt update
sudo apt install wireguard -y

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
append="
ListenPort = $WIREGUARD_PORT
Address = $WIREGUARD_VPS_IP/24

[Peer]
PublicKey = $WIREGUARD_DMZ_PUBLIC_KEY
AllowedIPs = $WIREGUARD_DMZ_IP/32"

# Add the following to the end of the file
echo "$append" | sudo tee -a /etc/wireguard/wg0.conf >/dev/null

# Enable Wireguard
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Configure UFW
echo "Configuring firewall..."
## Check which interface is the default
default_interface=$(ip route | grep default | head -n 1 | awk '{print $5}')
echo "Default interface: $default_interface"

## Remove old rules with comment "VPS to DMZ" and "DMZ to VPS"
echo "Removing old rules..."
comment1="DMZ to VPS"
comment2="VPS to DMZ"

# Get the rule numbers with the specified comments
rule_numbers=$(sudo iptables -L -n --line-numbers | grep -E "($comment1|$comment2)" | awk '{print $1}')
readarray -t rule_numbers <<<"$rule_numbers"
# Remove the rules based on their numbers
for rule_number in "${rule_numbers[@]}"; do
	sudo iptables -D INPUT "$rule_number"
	sudo iptables -D OUTPUT "$rule_number"
	sudo iptables -D FORWARD "$rule_number"
	sudo iptables -t nat -D PREROUTING "$rule_number"
	sudo iptables -t nat -D POSTROUTING "$rule_number"
done

echo "Rules with comments '$comment1' or '$comment2' have been removed."

## Create a new iptables chain and set the default rules to DROP
echo "Creating new iptables profile..."
sudo iptables -P FORWARD DROP -m comment --comment "VPS to DMZ"

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

# Test connection
echo "Testing connection..."
response=$(ping -c 1 "$WIREGUARD_DMZ_IP")
echo "If you see a response, the connection is working."
echo "If you don't see a response, check the configuration and try again."
echo "If you still don't see a response, check the firewall rules and try again."

if [[ "$response" == *"1 received"* ]]; then
	echo "Connection successful."
else
	echo "Connection failed."
	exit 1
fi

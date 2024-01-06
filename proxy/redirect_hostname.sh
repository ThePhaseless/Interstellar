# Ask what is the ip of server
read -p "What is the IP of the server (from Tailscale)? (e.g. 100.123.123.123): " SERVER_IP
# Ask what is the hostname of server
read -p "What is the hostname of the server? (e.g. example.com): " SERVER_HOSTNAME

# Disable systemd-resolved
echo "Disabling systemd-resolved..."
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
echo "Done..."

# Remove symlink for resolv.conf
echo "Removing symlink for resolv.conf..."
sudo unlink /etc/resolv.conf
echo "Done..."

# Install DnsMasq
echo "Installing DnsMasq..."
sudo apt install -y dnsmasq
echo "Done..."

# Configure DnsMasq
echo "Configuring DnsMasq..."
# Create redirect.conf and add to it the following:
# address=/HOSTNAME/SERVER_IP
sudo bash -c "echo \"address=/$SERVER_HOSTNAME/$SERVER_IP\" > /etc/dnsmasq.d/redirect.conf"

# Restart DnsMasq
sudo systemctl restart dnsmasq
echo "Done..."

# Add DnsMasq to startup
echo "Adding DnsMasq to startup..."
sudo systemctl enable dnsmasq
echo "Done..."

# Add DnsMasq to resolv.conf as first nameserver
echo "Adding DnsMasq to resolv.conf..."
sudo sed -i '1s/^/nameserver 127.0.0.1\n/' /etc/resolv.conf
sudo sed -i '1s/^/nameserver 1.1.1.1\n/' /etc/resolv.conf
echo "Done..."

# Add DnsMasq to dhclient.conf
echo "Adding DnsMasq to dhclient.conf..."
sudo bash -c "echo \"prepend domain-name-servers 127.0.0.1;\" >> /etc/dhcp/dhclient.conf"
sudo bash -c "echo \"request subnet-mask, broadcast-address, time-offset, routers, domain-name, domain-name-servers, host-name, netbios-name-servers, netbios-scope;\" >> /etc/dhcp/dhclient.conf"
echo "Done..."

# Restart dhclient
echo "Restarting dhclient..."
sudo dhclient -r
sudo dhclient
echo "Done..."

# Restart DnsMasq
echo "Restarting DnsMasq..."
sudo systemctl restart dnsmasq
echo "Done..."

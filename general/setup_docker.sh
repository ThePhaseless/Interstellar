echo "Installing Docker and Docker Compose..."

# Remove old versions of Docker
echo "Removing old versions of Docker..."
sudo apt docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc

# Install Docker
# Add Docker's official GPG key:
echo "Adding Docker's official GPG key..."
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update

# Install Docker Engine:
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Create the docker group:
sudo groupadd docker

# Enable Docker to start on boot:
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Add your user to the docker group:
sudo usermod -aG docker "$USER"
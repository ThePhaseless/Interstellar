#!/bin/bash

# Check if $CONFIG_PATH is set
if [ -z "$CONFIG_PATH" ]; then
	echo "CONFIG_PATH is not set. What is the path to your portainer config folder? (e.g. ~/config/Portainer)"
	read -r CONFIG_PATH
fi

# Pull and run Portainer
echo "Pulling and running Portainer in $CONFIG_PATH/Portainer..."
docker run -d -p "9000:9000" --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v "$CONFIG_PATH"/Portainer:/data portainer/portainer-ce
echo "Done..."

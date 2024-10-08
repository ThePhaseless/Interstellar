#!/bin/bash
set -e

source .env

if [ ! -d "$CONFIG_PATH"/Home/HomeAssistant/custom_components/hacs ]; then
    command="wget -O - https://get.hacs.xyz | bash"
    echo "$command" | docker exec -i HomeAssistant bash
    docker restart HomeAssistant
fi

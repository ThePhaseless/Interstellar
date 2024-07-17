#!/bin/bash
set -e

source .env
config_path=$CONFIG_PATH

if [ ! -d "$config_path"/Config/Home/HomeAssistant/custom_components/hacs ]; then
    command="wget -O - https://get.hacs.xyz | bash"
    echo $command | docker exec -i HomeAssistant bash
    docker restart HomeAssistant
fi

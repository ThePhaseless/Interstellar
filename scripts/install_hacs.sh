#!/bin/bash

source .env
config_path=$CONFIG_PATH

if [ ! -d "$config_path"/Config/Home/HomeAssistant/custom_components/hacs ]; then
    docker exec -it HomeAssistant "wget -O - https://get.hacs.xyz | bash -"
    docker restart HomeAssistant
fi

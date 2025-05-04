#!/bin/bash
set -e

source .env

command="wget -O - https://get.hacs.xyz | bash"
echo "$command" | docker exec -i HomeAssistant bash
docker restart HomeAssistant

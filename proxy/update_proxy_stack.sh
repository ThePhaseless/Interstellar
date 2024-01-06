#!/bin/bash
# if PROXY is not said, ask if script should continue

if [ -z "$PROXY" ]; then
    read -r -p "PROXY is not set, continue? (Y/n): " answer
    case ${answer,,} in
    n*)
        echo "Cancelling..."
        exit
        ;;
    esac
fi

# Check if proxy.env exists
if [ ! -f ./.env ]; then
    echo ".env does not exist, creating..."
    cp ./.env.example ./.env
    echo "Change the values in .env and run this script again."
    exit
fi

echo "Starting Traefik stack"
docker compose --env-file ./.env up -d

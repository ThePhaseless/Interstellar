#!/bin/bash

# Check if proxy.env exists
if [ ! -f ./.env ]; then
    echo ".env does not exist, creating..."
    cp ./.env.example ./.env
    echo "Change the values in .env and run this script again."
    exit
fi

echo "Starting Traefik stack"
docker compose --env-file ./.env up -d

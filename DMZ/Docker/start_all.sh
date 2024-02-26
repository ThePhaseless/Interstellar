#!/bin/bash
# exit on error
set -e

# Change to the directory of this script
cd Compose || exit 1

# Get all docker-compose files
compose_files=$(find . -type f -name "docker-compose.*.yaml")

# Start all services
for file in $compose_files; do
  docker compose -f "$file" up -d
done

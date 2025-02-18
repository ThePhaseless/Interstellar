#!/bin/bash
set -e

sudo git pull --rebase
docker compose up -d --remove-orphans --pull always
docker system prune -a -f

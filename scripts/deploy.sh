#!/bin/bash
set -e
git commit -am "[skip ci] Synced latest changes"
git pull --rebase
git push
docker compose up -d --remove-orphans --pull always
docker system prune -a -f

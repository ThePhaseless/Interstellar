#!/bin/bash

sudo git pull
docker compose down
docker compose pull
docker compose up -d --remove-orphans
docker system prune -a -f

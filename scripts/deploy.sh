#!/bin/bash

sudo git pull
docker compose up -d --remove-orphans --pull always
docker system prune -a -f

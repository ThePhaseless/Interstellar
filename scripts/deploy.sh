#!/bin/bash

sudo git pull
docker compose up -d --remove-orphans

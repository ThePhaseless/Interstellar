#!/bin/bash
# =============================================================================
# Configure Download Client (qBittorrent) in *arr apps
# =============================================================================
# Usage: configure-download-client.sh <app-name> <app-url> <api-key>

APP_NAME=$1
APP_URL=$2
API_KEY=$3

if [ -z "$APP_NAME" ] || [ -z "$APP_URL" ] || [ -z "$API_KEY" ]; then
  echo "Usage: $0 <app-name> <app-url> <api-key>"
  exit 1
fi

# qBittorrent configuration
QB_HOST="qbittorrent.media.svc.cluster.local"
QB_PORT="8080"

echo "Configuring qBittorrent as download client for $APP_NAME..."

# Check if download client already exists
EXISTING=$(curl -s -X GET "${APP_URL}/api/v3/downloadclient" \
  -H "X-Api-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | grep -c "qBittorrent" || echo "0")

if [ "$EXISTING" != "0" ]; then
  echo "Download client already configured for $APP_NAME"
  exit 0
fi

# Add qBittorrent as download client
curl -s -X POST "${APP_URL}/api/v3/downloadclient" \
  -H "X-Api-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "enable": true,
    "protocol": "torrent",
    "priority": 1,
    "removeCompletedDownloads": true,
    "removeFailedDownloads": true,
    "name": "qBittorrent",
    "fields": [
      {"name": "host", "value": "'${QB_HOST}'"},
      {"name": "port", "value": '${QB_PORT}'},
      {"name": "useSsl", "value": false},
      {"name": "urlBase", "value": ""},
      {"name": "username", "value": ""},
      {"name": "password", "value": ""},
      {"name": "movieCategory", "value": "movies"},
      {"name": "tvCategory", "value": "tv"},
      {"name": "recentMoviePriority", "value": 0},
      {"name": "olderMoviePriority", "value": 0},
      {"name": "recentTvPriority", "value": 0},
      {"name": "olderTvPriority", "value": 0},
      {"name": "initialState", "value": 0},
      {"name": "sequentialOrder", "value": false},
      {"name": "firstAndLast", "value": false}
    ],
    "implementationName": "qBittorrent",
    "implementation": "QBittorrent",
    "configContract": "QBittorrentSettings",
    "tags": []
  }'

echo "Download client configured for $APP_NAME"

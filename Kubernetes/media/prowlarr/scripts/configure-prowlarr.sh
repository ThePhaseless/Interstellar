#!/bin/sh
set -e

echo "Configuring Prowlarr indexers..."

RADARR_PAYLOAD='{
  "syncLevel": "fullSync",
  "enable": true,
  "fields": [
    { "name": "prowlarrUrl", "value": "http://prowlarr:9696" },
    { "name": "baseUrl", "value": "http://radarr:7878" },
    { "name": "apiKey", "value": "'$RADARR_API_KEY'" },
    {
      "name": "syncCategories",
      "value": [
        2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060, 2070, 2080, 2090
      ]
    },
    {
      "name": "syncRejectBlocklistedTorrentHashesWhileGrabbing",
      "value": false
    }
  ],
  "implementationName": "Radarr",
  "implementation": "Radarr",
  "configContract": "RadarrSettings",
  "infoLink": "https://wiki.servarr.com/prowlarr/supported#radarr",
  "tags": [],
  "name": "Radarr"
}'

echo "Adding Radarr to Prowlarr..."
curl "http://prowlarr:9696/api/v1/applications" -fv \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: $PROWLARR_API_KEY" \
  --data-raw "$RADARR_PAYLOAD" || \
  curl -X PUT "http://prowlarr:9696/api/v1/applications/1" -fv \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: $PROWLARR_API_KEY" \
  --data-raw "$RADARR_PAYLOAD"

SONARR_PAYLOAD='{
  "syncLevel": "fullSync",
  "enable": true,
  "fields": [
    { "name": "prowlarrUrl", "value": "http://prowlarr:9696" },
    { "name": "baseUrl", "value": "http://sonarr:8989" },
    { "name": "apiKey", "value": "'$SONARR_API_KEY'" },
    {
      "name": "syncCategories",
      "value": [5000, 5010, 5020, 5030, 5040, 5045, 5050, 5090]
    },
    { "name": "animeSyncCategories", "value": [5070] },
    { "name": "syncAnimeStandardFormatSearch", "value": true },
    {
      "name": "syncRejectBlocklistedTorrentHashesWhileGrabbing",
      "value": false
    }
  ],
  "implementationName": "Sonarr",
  "implementation": "Sonarr",
  "configContract": "SonarrSettings",
  "infoLink": "https://wiki.servarr.com/prowlarr/supported#sonarr",
  "tags": [],
  "name": "Sonarr"
}'

echo "Adding Sonarr to Prowlarr..."
curl 'http://prowlarr:9696/api/v1/applications?' -vf \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: $PROWLARR_API_KEY" \
  -d "$SONARR_PAYLOAD" || \
  curl -X PUT "http://prowlarr:9696/api/v1/applications/2" -vf \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: $PROWLARR_API_KEY" \
  --data-raw "$SONARR_PAYLOAD"

echo "Prowlarr configuration completed!"
